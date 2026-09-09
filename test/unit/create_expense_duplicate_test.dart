import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/expenses/domain/entities/category_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/expense_entity.dart';
import 'package:rental_ledger/features/expenses/domain/repositories/expense_repository.dart';
import 'package:rental_ledger/features/expenses/presentation/providers/expense_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';

/// Guards the Issue-3 duplicate-submission fix on Add Expense.
///
/// A fast double-tap on "Submit Expense" (before the submit button rebuilds
/// disabled) previously started two creates: two uploads of the receipt and two
/// expense documents. The notifier now sets a `_submitting` flag synchronously
/// before its first await, so a second call landing while the first is in
/// flight is dropped. The page-level `_submitting` guard is belt-and-braces on
/// top of this; these tests lock the notifier behaviour.
final _now = DateTime(2026, 9);

final _memberUser = UserEntity(
  uid: 'member-1',
  email: 'member@example.com',
  displayName: 'Member',
  createdAt: _now,
);

final _house = HouseEntity(
  houseId: 'house-1',
  houseName: 'Sunset Villa',
  inviteCode: 'AB12CD',
  treasurerId: 'treasurer-1',
  createdAt: _now,
);

/// Stub repository that records `createExpense` calls — the assertion that the
/// guarded duplicate never reaches the data layer.
class _RecordingExpenseRepository implements ExpenseRepository {
  final List<ExpenseEntity> created = [];

  @override
  Future<ExpenseEntity> createExpense(ExpenseEntity expense) async {
    created.add(expense);
    return expense;
  }

  @override
  Future<List<CategoryEntity>> getCategories(String houseId) async =>
      CategoryEntity.defaults;

  @override
  Future<void> seedDefaultCategories(String houseId) async {}

  @override
  Future<ExpenseEntity> updateExpense(ExpenseEntity expense) =>
      throw UnimplementedError();

  @override
  Future<void> deleteExpense(String expenseId) => throw UnimplementedError();

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

ProviderContainer _containerFor(_RecordingExpenseRepository repo) {
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => _memberUser),
      currentHouseProvider.overrideWith((ref) => _house),
      expenseRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('createExpense duplicate-submit guard (Issue 3)', () {
    test('a second submit while the first is in flight creates ONE expense',
        () async {
      final repo = _RecordingExpenseRepository();
      final container = _containerFor(repo);
      final notifier = container.read(createExpenseProvider.notifier);

      // Fire the second submit synchronously after the first (before the first
      // has awaited) — the exact double-tap window. No receipt path is set, so
      // no upload branch runs and no data source is touched.
      final first = notifier.createExpense(
        title: 'Groceries',
        description: 'Weekly shop',
        categoryId: 'food',
        amount: 42.5,
        paymentSource: 'personal',
      );
      final duplicate = notifier.createExpense(
        title: 'Groceries',
        description: 'Weekly shop',
        categoryId: 'food',
        amount: 42.5,
        paymentSource: 'personal',
      );

      expect(await first, isNull);
      // The guard returns a no-op success: the work IS already in progress and
      // will complete, so the caller (which navigates on success) is correct to
      // proceed — but nothing was duplicated.
      expect(await duplicate, isNull);
      expect(repo.created, hasLength(1),
          reason: 'only the first submit may reach the repository');
    });

    test('the guard resets after completion so a later submit still works',
        () async {
      final repo = _RecordingExpenseRepository();
      final container = _containerFor(repo);
      final notifier = container.read(createExpenseProvider.notifier);

      expect(
        await notifier.createExpense(
          title: 'Groceries',
          categoryId: 'food',
          amount: 42.5,
          paymentSource: 'central',
        ),
        isNull,
      );
      expect(repo.created, hasLength(1));

      // After the first completes, `_submitting` is cleared in `finally` — a
      // genuinely new submit (e.g. the page navigated away and back) proceeds.
      expect(
        await notifier.createExpense(
          title: 'Utilities',
          categoryId: 'utilities',
          amount: 88.0,
          paymentSource: 'central',
        ),
        isNull,
      );
      expect(repo.created, hasLength(2));
    });
  });
}
