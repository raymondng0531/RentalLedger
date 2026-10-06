// A sample-data demo of the REAL app, for visual checks and screenshots.
//
// No Firebase, no sign-in, no real data: Firebase is reported as unavailable
// (so every live provider stays empty instead of touching the network) and the
// signed-in user, house, dashboard and bills are fictional sample data.
//
//   flutter run -d chrome -t tool/screenshots/demo_main.dart
//
// Only the Dashboard is populated; other tabs show their empty states.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rental_ledger/app/app.dart';
import 'package:rental_ledger/core/services/firebase_service.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/domain/repositories/auth_repository.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/dashboard/domain/entities/activity_item.dart';
import 'package:rental_ledger/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:rental_ledger/features/dashboard/domain/entities/monthly_summary.dart';
import 'package:rental_ledger/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:rental_ledger/features/expenses/domain/entities/bill_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/category_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/deposit_request_entity.dart';
import 'package:rental_ledger/features/expenses/presentation/providers/expense_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';
import 'package:rental_ledger/features/members/domain/repositories/house_repository.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';

final _now = DateTime.now();

final _bob = UserEntity(
  uid: 'bob',
  email: 'bob@example.com',
  displayName: 'Bob',
  createdAt: _now,
);

final _house = HouseEntity(
  houseId: 'demo',
  houseName: 'Sunset Villa',
  inviteCode: 'DEMO42',
  treasurerId: 'bob',
  createdAt: _now,
);

final _members = [
  HouseMemberEntity(
    memberId: 'm1',
    houseId: 'demo',
    userId: 'bob',
    role: 'Treasurer',
    joinedAt: _now,
    displayName: 'Bob',
  ),
  HouseMemberEntity(
    memberId: 'm2',
    houseId: 'demo',
    userId: 'alice',
    joinedAt: _now,
    displayName: 'Alice',
  ),
];

final _dashboard = DashboardData(
  balance: 2450,
  houseName: 'Sunset Villa',
  monthly: const MonthlySummary(
    moneyIn: 1800,
    moneyOut: 620.5,
    pendingReimbursements: 42.5,
    pendingCount: 1,
  ),
  pendingItems: [
    ActivityItem(
      id: 'e1',
      type: 'expense',
      title: 'Cleaning supplies',
      amount: 42.5,
      date: _now.subtract(const Duration(days: 1)),
      status: 'pending',
      categoryId: 'household',
      paymentSource: 'personal',
    ),
  ],
  recentActivity: [
    ActivityItem(
      id: 't1',
      type: 'deposit',
      title: 'Monthly Rental',
      amount: 600,
      date: _now.subtract(const Duration(days: 2)),
    ),
    ActivityItem(
      id: 't2',
      type: 'payment',
      title: 'Bill: Internet',
      amount: -129,
      date: _now.subtract(const Duration(days: 3)),
      categoryId: 'internet',
    ),
  ],
);

class _DemoAuthRepository implements AuthRepository {
  @override
  final ValueNotifier<UserEntity?> currentUserNotifier = ValueNotifier(_bob);

  @override
  UserEntity? get currentUser => currentUserNotifier.value;

  @override
  Stream<UserEntity?> authStateChanges() => Stream.value(currentUser);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DemoHouseRepository implements HouseRepository {
  @override
  final ValueNotifier<HouseEntity?> currentHouseNotifier = ValueNotifier(_house);

  @override
  final ValueNotifier<bool> houseResolvedNotifier = ValueNotifier(true);

  @override
  HouseEntity? get currentHouse => currentHouseNotifier.value;

  @override
  bool get hasHouse => true;

  @override
  bool get isHouseResolved => true;

  @override
  Future<void> loadUserHouse(String userId) async {}

  @override
  Future<void> clearCurrentHouse() async {}

  @override
  Stream<List<HouseMemberEntity>> membersStream(String houseId) =>
      Stream.value(_members);

  @override
  Stream<List<HouseMemberEntity>> allMembersStream(String houseId) =>
      Stream.value(_members);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  runApp(
    ProviderScope(
      overrides: [
        // Live providers check this and stay empty instead of using Firebase.
        firebaseInitResultProvider.overrideWithValue(
          const FirebaseInitResult(false, 'demo mode'),
        ),
        authRepositoryProvider.overrideWithValue(_DemoAuthRepository()),
        houseRepositoryProvider.overrideWithValue(_DemoHouseRepository()),
        dashboardDataProvider.overrideWith((ref) => Stream.value(_dashboard)),
        categoriesProvider.overrideWith((ref) async => CategoryEntity.defaults),
        billsProvider.overrideWith(
          (ref) => Stream.value([
            BillEntity(
              billId: 'b1',
              houseId: 'demo',
              title: 'Electricity',
              amount: 180,
              dueDate: _now.add(const Duration(days: 5)),
              isRecurring: true,
              createdAt: _now,
            ),
          ]),
        ),
        pendingDepositRequestsProvider.overrideWith(
          (ref) => Stream.value([
            DepositRequestEntity(
              requestId: 'req-1',
              houseId: 'demo',
              amount: 300,
              paidByUserId: 'alice',
              submittedBy: 'alice',
              createdAt: _now,
            ),
          ]),
        ),
      ],
      child: const RentalLedgerApp(),
    ),
  );
}
