import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/expenses/domain/entities/category_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/expense_entity.dart';
import 'package:rental_ledger/features/expenses/domain/repositories/expense_repository.dart';
import 'package:rental_ledger/features/expenses/presentation/providers/expense_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/core/utils/failure_messages.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Guards the V1.0 "Delete Pending Expense" permission model (FR-010):
///
/// A member may delete their OWN expense while it is still Pending. They may
/// NOT delete another member's expense, nor their own once it has been
/// Approved / Paid / Rejected.
///
/// The notifier enforces both checks (owner + status) with a
/// [PermissionFailure] BEFORE the repository is touched, so these tests are
/// fully deterministic without Firebase. The allowed path stubs the repository
/// to prove the delete is actually invoked.
const _permissionNotOwner = 'You can only delete your own expense.';
const _permissionNotPending = 'Only pending expenses can be deleted.';

/// The sign-in guard as the member reads it. The notifier now returns the
/// stable code rather than the sentence, so the assertion below pins both.
const _notAuthenticated = 'Not authenticated.';

late AppLocalizations _en;

final _now = DateTime(2026, 9);

final _ownerUser = UserEntity(
  uid: 'member-1',
  email: 'owner@example.com',
  displayName: 'Owner',
  createdAt: _now,
);

final _otherUser = UserEntity(
  uid: 'member-2',
  email: 'other@example.com',
  displayName: 'Other Member',
  createdAt: _now,
);

final _house = HouseEntity(
  houseId: 'house-1',
  houseName: 'Sunset Villa',
  inviteCode: 'AB12CD',
  treasurerId: 'treasurer-1',
  createdAt: _now,
);

ExpenseEntity _expense({
  String status = 'pending',
  String purchasedBy = 'member-1',
}) =>
    ExpenseEntity(
      expenseId: 'exp-1',
      houseId: _house.houseId,
      purchasedBy: purchasedBy,
      title: 'Groceries',
      categoryId: 'food',
      amount: 42.5,
      paymentSource: 'personal',
      status: status,
      createdAt: _now,
    );

/// Stub repository that records `deleteExpense` calls. The delete notifier's
/// permission checks run first, so the owner+pending path reaches here while
/// every denied path never does — the empty [deletedIds] is the assertion that
/// no delete was attempted.
class _RecordingExpenseRepository implements ExpenseRepository {
  final List<String> deletedIds = [];

  @override
  Future<void> deleteExpense(String expenseId) async {
    deletedIds.add(expenseId);
  }

  @override
  Future<List<CategoryEntity>> getCategories(String houseId) async =>
      CategoryEntity.defaults;

  @override
  Future<void> seedDefaultCategories(String houseId) async {}

  @override
  Future<ExpenseEntity> createExpense(ExpenseEntity expense) =>
      throw UnimplementedError();

  @override
  Future<ExpenseEntity> updateExpense(ExpenseEntity expense) =>
      throw UnimplementedError();

  @override
  Future<ExpenseEntity?> getExpense(String expenseId) =>
      throw UnimplementedError();

  @override
  Future<List<ExpenseEntity>> getExpenses(String houseId,
          {String? status}) =>
      throw UnimplementedError();

  @override
  Future<ExpenseEntity> approveExpense(String expenseId, String treasurerId) =>
      throw UnimplementedError();

  @override
  Future<ExpenseEntity> rejectExpense(String expenseId, String treasurerId,
          {String? reason}) =>
      throw UnimplementedError();

  @override
  Future<ExpenseEntity> markPaid(String expenseId, String treasurerId) =>
      throw UnimplementedError();
}

/// A container whose signed-in user is [user], with an optional [repo]
/// override for the allowed-path test.
ProviderContainer _containerFor(
  UserEntity? user, {
  _RecordingExpenseRepository? repo,
}) {
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      currentHouseProvider.overrideWith((ref) => _house),
      if (repo != null)
        expenseRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('Delete Expense — owner + Pending only', () {
    test('owner deletes their own Pending expense (repo.deleteExpense called)',
        () async {
      final repo = _RecordingExpenseRepository();
      final container = _containerFor(_ownerUser, repo: repo);

      final error = await container
          .read(deleteExpenseProvider.notifier)
          .delete(_expense());

      expect(error, isNull, reason: 'owner + pending must be allowed');
      expect(repo.deletedIds, ['exp-1'],
          reason: 'the delete must reach the repository');
    });

    test('another member cannot delete the owner\'s Pending expense',
        () async {
      final repo = _RecordingExpenseRepository();
      final container = _containerFor(_otherUser, repo: repo);

      final error = await container
          .read(deleteExpenseProvider.notifier)
          .delete(_expense());

      expect(error, _permissionNotOwner);
      expect(repo.deletedIds, isEmpty,
          reason: 'no delete may reach the repository');
    });

    test('owner cannot delete their own expense after review', () async {
      // Approved / Paid / Rejected are all terminal for the submitter — the
      // expense has entered the Treasurer's workflow and must not be deleted.
      for (final status in ['approved', 'paid', 'rejected']) {
        final repo = _RecordingExpenseRepository();
        final container = _containerFor(_ownerUser, repo: repo);

        final error = await container
            .read(deleteExpenseProvider.notifier)
            .delete(_expense(status: status));

        expect(error, _permissionNotPending,
            reason: '$status expense must not be deletable');
        expect(repo.deletedIds, isEmpty,
            reason: '$status expense must not reach the repository');
      }
    });

    test('not authenticated returns an error and never deletes', () async {
      final repo = _RecordingExpenseRepository();
      final container = _containerFor(null, repo: repo);

      final error = await container
          .read(deleteExpenseProvider.notifier)
          .delete(_expense());

      expect(error, FailureCodes.notSignedIn);
      expect(FailureMessages.forError(error, _en), _notAuthenticated);
      expect(repo.deletedIds, isEmpty);
    });
  });
}
