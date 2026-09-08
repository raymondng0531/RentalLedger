import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/errors/failures.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/expenses/domain/entities/bill_entity.dart';
import 'package:rental_ledger/features/expenses/presentation/providers/expense_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';

/// Guards the V1.0 Treasurer-only permission enforcement for financial ops.
///
/// A regular Member must be rejected BEFORE any Firestore write happens for:
///   - Record Deposit
///   - Record Direct Payment
///   - Mark a Bill Paid (records a Direct Payment transaction)
/// while the house Treasurer must NOT be blocked by the same guards.
///
/// Firestore is never initialised here: the Member-denied paths short-circuit
/// in the notifier before the data source is touched, so they are fully
/// deterministic. For the Treasurer-allowed paths the assertion is that the
/// permission denial is NOT returned — the notifier proceeds toward the data
/// source (which, with no Firebase in tests, fails later with a non-permission
/// error). This is the invariant that would flip if the guard ever over-blocked
/// the Treasurer.
const _permissionDeposit = 'Only the Treasurer can record a deposit.';
const _permissionDirectPayment =
    'Only the Treasurer can record a direct payment.';

final _now = DateTime(2026, 9);

final _treasurerUser = UserEntity(
  uid: 'treasurer-1',
  email: 'treasurer@example.com',
  displayName: 'Treasurer',
  createdAt: _now,
);

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
  treasurerId: _treasurerUser.uid,
  createdAt: _now,
);

BillEntity _bill() => BillEntity(
      billId: 'bill-1',
      houseId: _house.houseId,
      title: 'Internet',
      amount: 99,
      dueDate: DateTime(2026, 10),
      createdAt: _now,
    );

/// A container whose signed-in user is [user].
ProviderContainer _containerFor(UserEntity user) {
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      currentHouseProvider.overrideWith((ref) => _house),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('Record Deposit — Treasurer-only', () {
    test('Member is denied (returns permission message, no write)', () async {
      final container = _containerFor(_memberUser);
      final error = await container
          .read(depositProvider.notifier)
          .deposit(amount: 100, notes: 'Top-up');
      expect(error, _permissionDeposit);
    });

    test('Treasurer is not denied by the permission guard', () async {
      final container = _containerFor(_treasurerUser);
      final error = await container
          .read(depositProvider.notifier)
          .deposit(amount: 100, notes: 'Top-up');
      expect(error, isNot(_permissionDeposit));
    });
  });

  group('Record Direct Payment — Treasurer-only', () {
    test('Member is denied (returns permission message, no write)', () async {
      final container = _containerFor(_memberUser);
      final error = await container
          .read(directPaymentProvider.notifier)
          .payDirectly(amount: 50, notes: 'Repair');
      expect(error, _permissionDirectPayment);
    });

    test('Treasurer is not denied by the permission guard', () async {
      final container = _containerFor(_treasurerUser);
      final error = await container
          .read(directPaymentProvider.notifier)
          .payDirectly(amount: 50, notes: 'Repair');
      expect(error, isNot(_permissionDirectPayment));
    });
  });

  group('Mark Bill Paid — Treasurer-only (records a Direct Payment)', () {
    test('Member is denied with a PermissionFailure', () async {
      final container = _containerFor(_memberUser);
      await expectLater(
        container.read(billActionsProvider.notifier).markPaid(_bill()),
        throwsA(isA<PermissionFailure>()),
      );
    });

    test('Treasurer is not denied by the permission guard', () async {
      final container = _containerFor(_treasurerUser);
      try {
        await container.read(billActionsProvider.notifier).markPaid(_bill());
        // If the data source were reachable this would succeed — that's fine.
      } on PermissionFailure {
        fail('Treasurer must be allowed to mark a bill as paid.');
      } catch (_) {
        // Any non-permission error (e.g. Firebase not configured in the test
        // env, which throws an Error) is acceptable: it proves the guard did
        // NOT block the Treasurer.
      }
    });
  });

  group('Member-facing bill controls stay open to Members', () {
    test('Remind Treasurer does not require the Treasurer role', () async {
      // remindTreasurer creates a cross-user notification for the house
      // Treasurer — a Member-facing action. It should not trip the guard.
      final container = _containerFor(_memberUser);
      // It reaches the notification data source only when house + user exist;
      // with no Firebase it may error, but it must NOT be a PermissionFailure.
      try {
        await container
            .read(billActionsProvider.notifier)
            .remindTreasurer(_bill());
      } on PermissionFailure {
        fail('Remind Treasurer must stay available to Members.');
      } catch (_) {
        // Non-permission outcome acceptable (Firebase not configured in tests,
        // or the notification write succeeding against a real backend).
      }
    });
  });
}
