// Generates the README screenshots from the REAL app screens, fed with
// made-up sample data â€” no sign-in, no Firebase, no real house data.
//
// Not part of `flutter test` (it lives under tool/). Regenerate with:
//
//   flutter test --update-goldens tool/screenshots/readme_screenshots_test.dart
//
// The PNGs are written to docs/screenshots/. (The deposit-request details page
// is not shot here: its receipt widget uses web-only code that does not
// compile in the test VM.)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/app/theme/app_theme.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/dashboard/domain/entities/activity_item.dart';
import 'package:rental_ledger/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:rental_ledger/features/dashboard/domain/entities/monthly_summary.dart';
import 'package:rental_ledger/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:rental_ledger/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:rental_ledger/features/expenses/domain/entities/bill_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/category_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/deposit_request_entity.dart';
import 'package:rental_ledger/features/expenses/presentation/pages/deposit_page.dart';
import 'package:rental_ledger/features/expenses/presentation/providers/expense_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';
import 'package:rental_ledger/features/notifications/presentation/providers/notification_provider.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

// â”€â”€ Sample data (all fictional) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final _now = DateTime.now();

final _bob = UserEntity(
  uid: 'bob',
  email: 'bob@example.com',
  displayName: 'Bob',
  createdAt: _now,
);

final _alice = UserEntity(
  uid: 'alice',
  email: 'alice@example.com',
  displayName: 'Alice',
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
  HouseMemberEntity(
    memberId: 'm3',
    houseId: 'demo',
    userId: 'chen',
    joinedAt: _now,
    displayName: 'Chen',
  ),
];

final _depositRequest = DepositRequestEntity(
  requestId: 'req-1',
  houseId: 'demo',
  amount: 300,
  paidByUserId: 'alice',
  submittedBy: 'alice',
  paymentMethod: 'Bank Transfer',
  periodLabel: '2026-10',
  purpose: 'Monthly Rental',
  notes: 'October rent share',
  createdAt: _now.subtract(const Duration(hours: 2)),
);

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
    ActivityItem(
      id: 't3',
      type: 'reimbursement',
      title: 'Reimbursement: Groceries',
      amount: -86.4,
      date: _now.subtract(const Duration(days: 5)),
      categoryId: 'food',
    ),
  ],
);

final _bills = [
  BillEntity(
    billId: 'b1',
    houseId: 'demo',
    title: 'Electricity',
    amount: 180,
    dueDate: _now.add(const Duration(days: 5)),
    isRecurring: true,
    createdAt: _now,
  ),
];

List<Override> _common(UserEntity user) => [
      currentUserProvider.overrideWith((ref) => user),
      currentHouseProvider.overrideWith((ref) => _house),
      membersStreamProvider.overrideWith((ref) => Stream.value(_members)),
      allMembersStreamProvider.overrideWith((ref) => Stream.value(_members)),
      notificationsStreamProvider.overrideWith((ref) => Stream.value(const [])),
      categoriesProvider.overrideWith((ref) async => CategoryEntity.defaults),
    ];

// â”€â”€ Harness â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

Future<void> _loadFonts() async {
  final fonts = '${Platform.environment['FLUTTER_ROOT']}'
      '/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('$fonts/$name').readAsBytes());

  // 'Roboto' for themed text; 'FlutterTest' / 'Ahem' are the test VM's
  // defaults for styles that name no family (the theme's button / app-bar
  // styles), which on a real device render in the platform font.
  for (final family in ['Roboto', 'FlutterTest', 'Ahem']) {
    final loader = FontLoader(family)
      ..addFont(read('roboto-regular.ttf'))
      ..addFont(read('roboto-medium.ttf'))
      ..addFont(read('roboto-bold.ttf'))
      ..addFont(read('roboto-black.ttf'));
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('materialicons-regular.otf'));
  await icons.load();
}

/// The theme's button / app-bar / chip styles name no font family, which on a
/// real device means the platform font (Roboto). The test VM's default font is
/// a placeholder, so name Roboto explicitly — for these screenshots only.
ThemeData _withRoboto(ThemeData t) {
  TextStyle? r(TextStyle? s) => s?.copyWith(fontFamily: 'Roboto');
  ButtonStyle? b(ButtonStyle? s) {
    final style = s?.textStyle?.resolve(const {});
    return s?.copyWith(
      textStyle: WidgetStatePropertyAll(
        (style ?? const TextStyle()).copyWith(fontFamily: 'Roboto'),
      ),
    );
  }

  return t.copyWith(
    appBarTheme: t.appBarTheme.copyWith(
      titleTextStyle: r(t.appBarTheme.titleTextStyle) ??
          t.textTheme.titleLarge,
    ),
    elevatedButtonTheme:
        ElevatedButtonThemeData(style: b(t.elevatedButtonTheme.style)),
    outlinedButtonTheme:
        OutlinedButtonThemeData(style: b(t.outlinedButtonTheme.style)),
    textButtonTheme: TextButtonThemeData(style: b(t.textButtonTheme.style)),
    filledButtonTheme:
        FilledButtonThemeData(style: b(t.filledButtonTheme.style)),
    chipTheme: t.chipTheme.copyWith(
      labelStyle: r(t.chipTheme.labelStyle),
      secondaryLabelStyle: r(t.chipTheme.secondaryLabelStyle),
    ),
    inputDecorationTheme: t.inputDecorationTheme.copyWith(
      hintStyle: r(t.inputDecorationTheme.hintStyle),
      labelStyle: r(t.inputDecorationTheme.labelStyle),
    ),
  );
}

Future<void> _shoot(
  WidgetTester tester, {
  required String name,
  required Widget page,
  required List<Override> overrides,
  Future<void> Function(WidgetTester)? interact,
}) async {
  tester.view.physicalSize = const Size(1170, 2532); // 390 x 844 @3x
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _withRoboto(AppTheme.lightTheme),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepaintBoundary(key: const ValueKey('shot'), child: page),
      ),
    ),
  );
  // Let streams emit and entrance animations finish.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  if (interact != null) {
    await interact(tester);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  await expectLater(
    find.byKey(const ValueKey('shot')),
    matchesGoldenFile('../../docs/screenshots/$name.png'),
  );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('dashboard (Treasurer)', (tester) async {
    await _shoot(
      tester,
      name: 'dashboard',
      page: const DashboardPage(),
      overrides: [
        ..._common(_bob),
        dashboardDataProvider.overrideWith((ref) => Stream.value(_dashboard)),
        billsProvider.overrideWith((ref) => Stream.value(_bills)),
        pendingDepositRequestsProvider
            .overrideWith((ref) => Stream.value([_depositRequest])),
      ],
    );
  });

  testWidgets('submit deposit (member)', (tester) async {
    await _shoot(
      tester,
      name: 'submit_deposit',
      page: const DepositPage(memberRequest: true),
      overrides: _common(_alice),
      interact: (tester) async {
        await tester.enterText(find.byType(TextFormField).first, '300.00');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'For month (optional)'),
          '2026-10',
        );
        FocusManager.instance.primaryFocus?.unfocus();
      },
    );
  });
}
