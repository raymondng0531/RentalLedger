import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/app/theme/app_theme.dart';
import 'package:rental_ledger/features/dashboard/presentation/widgets/pending_items_section.dart';
import 'package:rental_ledger/features/expenses/domain/entities/deposit_request_entity.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Member-submitted deposits awaiting the Treasurer appear in the dashboard's
/// Pending Items section alongside the claims.
void main() {
  DepositRequestEntity request(String id, String submittedBy) =>
      DepositRequestEntity(
        requestId: id,
        houseId: 'house-1',
        amount: 300,
        paidByUserId: submittedBy,
        submittedBy: submittedBy,
        createdAt: DateTime(2026, 10),
      );

  Future<void> pump(WidgetTester tester, PendingItemsSection section) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: section)),
        ),
      );

  testWidgets('a pending deposit request shows its submitter and amount, and '
      'replaces the empty state', (tester) async {
    await pump(
      tester,
      PendingItemsSection(
        items: const [],
        categoryMap: const {},
        depositRequests: [request('r1', 'member-1')],
        memberNames: const {'member-1': 'Aisyah'},
      ),
    );

    expect(find.text('Submitted by Aisyah'), findsOneWidget);
    expect(find.text('+RM 300.00'), findsOneWidget);
    expect(find.text('Deposit · waiting for Treasurer approval'), findsOneWidget);
    expect(find.byIcon(Icons.task_alt_rounded), findsNothing);
  });

  testWidgets('with no claims and no requests the empty state is unchanged',
      (tester) async {
    await pump(
      tester,
      const PendingItemsSection(items: [], categoryMap: {}),
    );
    expect(find.byIcon(Icons.task_alt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.savings_outlined), findsNothing);
  });

  testWidgets('an unknown submitter falls back to "Unknown Member"',
      (tester) async {
    await pump(
      tester,
      PendingItemsSection(
        items: const [],
        categoryMap: const {},
        depositRequests: [request('r1', 'ghost')],
      ),
    );
    expect(find.text('Submitted by Unknown Member'), findsOneWidget);
  });
}
