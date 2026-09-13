import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_ledger/app/router/route_names.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/dashboard/presentation/widgets/upcoming_bills_section.dart';
import 'package:rental_ledger/features/expenses/domain/entities/bill_entity.dart';
import 'package:rental_ledger/features/expenses/presentation/providers/expense_provider.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';

/// Phase D cover: the entry point Bill History is reached by.
///
/// Bill History is a read surface nobody can find unless a route leads to it,
/// so this guards the affordance the Dashboard's Upcoming Bills section offers
/// — present in both of the section's states (list and empty), pointed at
/// [RouteNames.billHistory], and without displacing the Treasurer's existing
/// Add Bill control.
///
/// A stand-in page occupies the Bill History route rather than the real
/// [BillHistoryPage]: what is under test is the navigation, and the real page
/// has its own suite (`bill_history_page_test.dart`).
///
/// Pure build + navigation — every provider the section reads is overridden,
/// so no Firebase is initialised.

final _now = DateTime(2026, 9);

final _house = HouseEntity(
  houseId: 'h1',
  houseName: 'Sunset Villa',
  inviteCode: 'AB12CD',
  treasurerId: 'u-treasurer',
  createdAt: _now,
);

final _treasurer = UserEntity(
  uid: 'u-treasurer',
  email: 'bob@example.com',
  displayName: 'Bob',
  createdAt: _now,
);

final _member = UserEntity(
  uid: 'u-member',
  email: 'alice@example.com',
  displayName: 'Alice',
  createdAt: _now,
);

BillEntity _bill({required String billId, required String title, bool isPaid = false}) {
  return BillEntity(
    billId: billId,
    houseId: 'h1',
    title: title,
    amount: 120,
    dueDate: DateTime(2026, 10),
    isPaid: isPaid,
    createdAt: _now,
  );
}

/// The section hosted on its own route, with Bill History on another.
Future<void> _pump(
  WidgetTester tester, {
  required UserEntity viewer,
  required List<BillEntity> bills,
  Size size = const Size(420, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder:
            (_, __) => const Scaffold(
              body: SingleChildScrollView(child: UpcomingBillsSection()),
            ),
      ),
      GoRoute(
        path: RouteNames.billHistory,
        builder:
            (_, __) => Scaffold(
              appBar: AppBar(title: const Text('BILL HISTORY ROUTE')),
              body: const SizedBox.shrink(),
            ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => viewer),
        currentHouseProvider.overrideWith((ref) => _house),
        billsProvider.overrideWith((ref) => Stream.value(bills)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump(); // Stream.value emits on the next microtask → data state.
  await tester.pumpAndSettle(); // Entrance animations.
}

void main() {
  group('Upcoming Bills → Bill History entry point', () {
    testWidgets('offers See all, and opens the Bill History route', (
      tester,
    ) async {
      await _pump(
        tester,
        viewer: _member,
        bills: [_bill(billId: 'b1', title: 'Electricity')],
      );

      expect(find.text('See all'), findsOneWidget);

      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();

      // Only the stand-in registered at RouteNames.billHistory renders this,
      // so finding it proves the affordance resolved to that route.
      expect(find.text('BILL HISTORY ROUTE'), findsOneWidget);

      // It is a PUSH, not a tab switch: Back returns to the Dashboard. That is
      // §7's "Back navigation works consistently", and it is why the location
      // itself is deliberately unchanged here.
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('BILL HISTORY ROUTE'), findsNothing);
      expect(find.text('Upcoming Bills'), findsOneWidget);
    });

    testWidgets('is offered even when there are no unpaid bills', (
      tester,
    ) async {
      // The section only lists unpaid bills, so the route to the settled ones
      // must not be hidden behind there being something left to list.
      await _pump(
        tester,
        viewer: _member,
        bills: [_bill(billId: 'b1', title: 'Electricity', isPaid: true)],
      );

      expect(find.text('No upcoming bills'), findsOneWidget);
      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();

      expect(find.text('BILL HISTORY ROUTE'), findsOneWidget);
    });

    testWidgets('leaves the Treasurer\'s Add Bill control in place', (
      tester,
    ) async {
      await _pump(
        tester,
        viewer: _treasurer,
        bills: [_bill(billId: 'b1', title: 'Electricity')],
      );

      // Both controls coexist — the entry point is additive, not a swap.
      expect(find.text('See all'), findsOneWidget);
      expect(find.text('Add Bill'), findsOneWidget);
    });

    testWidgets('a non-Treasurer sees See all but no Add Bill', (
      tester,
    ) async {
      await _pump(
        tester,
        viewer: _member,
        bills: [_bill(billId: 'b1', title: 'Electricity')],
      );

      expect(find.text('See all'), findsOneWidget);
      expect(find.text('Add Bill'), findsNothing);
    });

    testWidgets('the header fits a narrow phone without overflow', (
      tester,
    ) async {
      // See all sits beside Add Bill for the Treasurer, so 360px is the width
      // where three header items could collide.
      await _pump(
        tester,
        viewer: _treasurer,
        bills: [_bill(billId: 'b1', title: 'Electricity')],
        size: const Size(360, 900),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('See all'), findsOneWidget);
      expect(find.text('Add Bill'), findsOneWidget);
      expect(find.text('Upcoming Bills'), findsOneWidget);
    });
  });
}
