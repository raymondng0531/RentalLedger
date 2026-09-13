import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/reports/presentation/pages/reports_page.dart';
import 'package:rental_ledger/features/reports/presentation/providers/reports_provider.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

Widget _buildReports(ReportsData data) {
  return ProviderScope(
    overrides: [
      reportsProvider.overrideWith((ref) => Stream.value(data)),
    ],
    // Mirrors `app.dart`: the period chips are localized, so the harness
    // must supply the same delegates the real app does.
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReportsPage(),
    ),
  );
}

const ReportsData _sampleData = ReportsData(
  totalExpenses: 350,
  totalDeposits: 800,
  // Money In − Money Out = Balance (800 − 600 = 200), mirroring a real
  // household where Money Out (600) includes reimbursements, direct and bill
  // payments beyond just the paid expense claims (350).
  moneyIn: 800,
  moneyOut: 600,
  balance: 200,
  allTimeBalance: 200,
  highestCategoryName: 'Rent',
  highestCategoryAmount: 200,
  largestExpense: 150,
  averageMonthlyExpense: 116.67,
  avgExpenseClaim: 175,
  avgDeposit: 400,
  largestDeposit: 600,
  billsPaid: 1,
  billsPending: 2,
  // The money-out breakdown always sums to moneyOut in real reports; canned
  // data mirrors that so "Where the Money Goes" renders its buckets.
  moneyOutBreakdown: MoneyOutBreakdown(
    expenseReimbursements: 400,
    directPayments: 150,
    billPayments: 50,
  ),
  categoryBreakdown: [
    // Slices sweep clockwise from 0° (east): Food ≈ 0°–60°, Rent ≈
    // 60°–180°, Utilities ≈ 180°–360°.
    CategorySpending(name: 'Food', amount: 100, color: 0xFF16A34A),
    CategorySpending(name: 'Rent', amount: 200, color: 0xFF2563EB),
    CategorySpending(name: 'Utilities', amount: 50, color: 0xFFF97316),
  ],
  monthlyTrend: [
    MonthlyComparison(month: 'Aug', moneyIn: 800, moneyOut: 600),
  ],
);

/// A report with no money movement at all — the page shows an empty state.
const ReportsData _emptyData = ReportsData();

Future<void> _pumpReports(WidgetTester tester, ReportsData data) async {
  // The page is a ListView; give the viewport enough height that every
  // section (including the Monthly Trend card) actually gets built.
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_buildReports(data));
  await tester.pumpAndSettle();
}

/// Returns a point `radius` px from the pie centre at `angleDegrees`
/// (clockwise from the +x axis, matching fl_chart's canvas coordinates).
Offset _pointOnSlice(Rect pieRect, double angleDegrees, double radius) {
  final radians = angleDegrees * math.pi / 180;
  return pieRect.center +
      Offset(math.cos(radians) * radius, math.sin(radians) * radius);
}

void main() {
  testWidgets('renders the pie and bar charts', (tester) async {
    await _pumpReports(tester, _sampleData);

    expect(find.byType(PieChart), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    // The legend lists every category.
    expect(find.text('Food'), findsOneWidget);
  });

  testWidgets('summary shows Money In / Money Out / Current Balance',
      (tester) async {
    await _pumpReports(tester, _sampleData);

    // "Money In"/"Money Out" appear in both the summary cards and the monthly
    // trend legend, so check for at least one; the balance label is unique.
    expect(find.text('Money In'), findsWidgets);
    expect(find.text('Money Out'), findsWidgets);
    expect(find.text('Current Balance'), findsOneWidget);
    // On the default all-time report the Net/all-time call-out is not shown.
    expect(find.text('Net'), findsNothing);
    expect(find.textContaining('Central Account balance (all time)'),
        findsNothing);
    // The old, misleading labels are gone.
    expect(find.text('Total Expenses'), findsNothing);
    expect(find.text('Total Deposits'), findsNothing);
    expect(find.text('Net Flow'), findsNothing);
  });

  testWidgets('insights show the analytics cards incl. deposits and bills',
      (tester) async {
    await _pumpReports(tester, _sampleData);

    // The original five expense analytics…
    expect(find.text('Highest Expense Category'), findsOneWidget);
    // The category name is the card's subtitle (scoped to the insight grid,
    // since 'Rent' also appears in the category legend).
    expect(
      find.descendant(
        of: find.byType(GridView),
        matching: find.text('Rent'),
      ),
      findsOneWidget,
    );
    expect(find.text('Largest Expense Claim'), findsOneWidget);
    expect(find.text('Expense Reimbursements'), findsOneWidget);
    expect(find.text('Pending Reimbursements'), findsOneWidget);
    expect(find.text('Average Monthly Expense'), findsOneWidget);

    // …plus the new deposit and bills analytics.
    expect(find.text('Average Deposit'), findsOneWidget);
    expect(find.text('Largest Deposit'), findsOneWidget);
    expect(find.text('Bills Paid'), findsOneWidget);
    expect(find.text('Bills Pending'), findsOneWidget);
  });

  testWidgets('shows the "Where the Money Goes" money-out breakdown',
      (tester) async {
    await _pumpReports(tester, _sampleData);

    expect(find.text('Where the Money Goes'), findsOneWidget);
    // Buckets with money are listed; the empty Adjustment bucket is skipped.
    expect(find.text('Expense reimbursements'), findsOneWidget);
    expect(find.text('Direct payments'), findsOneWidget);
    expect(find.text('Bill payments'), findsOneWidget);
    expect(find.text('Adjustments'), findsNothing);
    // The card describes the source total.
    expect(find.textContaining('of Money Out'), findsOneWidget);
  });

  testWidgets('selecting a period flips the third box to Net and reveals the '
      'all-time balance note', (tester) async {
    await _pumpReports(tester, _sampleData);

    // The filter bar offers every period.
    expect(find.text('All time'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Last 3 months'), findsOneWidget);
    expect(find.text('This year'), findsOneWidget);
    expect(find.text('Custom range'), findsOneWidget);

    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();

    // Under a period the summary reconciles to the period's Net…
    expect(find.text('Net'), findsOneWidget);
    expect(find.text('Current Balance'), findsNothing);
    // …and the true all-time account balance is called out beneath it.
    expect(find.textContaining('Central Account balance (all time)'),
        findsOneWidget);
  });

  testWidgets('a period with no activity offers "Show all time" to reset',
      (tester) async {
    await _pumpReports(tester, _emptyData);

    expect(find.text('No reports yet'), findsOneWidget);

    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();

    // The filtered empty state replaces the brand-new-house one…
    expect(find.text('Nothing in this period'), findsOneWidget);
    expect(find.text('Show all time'), findsOneWidget);

    // …and tapping it returns to the all-time empty state.
    await tester.tap(find.text('Show all time'));
    await tester.pumpAndSettle();
    expect(find.text('No reports yet'), findsOneWidget);
  });

  testWidgets('bar chart tooltip is configured to stay inside the chart',
      (tester) async {
    await _pumpReports(tester, _sampleData);

    final barChart = tester.widget<BarChart>(find.byType(BarChart));
    final tooltip = barChart.data.barTouchData.touchTooltipData;
    // Without these, fl_chart draws the tooltip centred on the bar and it
    // gets clipped when the bar sits near the chart edge.
    expect(tooltip.fitInsideHorizontally, isTrue,
        reason: 'tooltip must shift inwards horizontally near an edge');
    expect(tooltip.fitInsideVertically, isTrue,
        reason: 'tooltip must stay inside the chart vertically');
  });

  testWidgets(
      'tapping a slice selects it; tapping outside clears it without throwing',
      (tester) async {
    await _pumpReports(tester, _sampleData);

    const hint = 'Tap a slice to see details';
    expect(find.text(hint), findsOneWidget);

    final pieRect = tester.getRect(find.byType(PieChart));

    // Tap inside the "Food" slice (mid of its arc, mid of the ring).
    await tester.tapAt(_pointOnSlice(pieRect, 30, 50));
    await tester.pumpAndSettle();

    // Selection shown: detail panel now shows "Food" next to the legend.
    expect(find.text(hint), findsNothing);
    expect(find.text('Food'), findsNWidgets(2));

    // Tap the hollow centre (outside every slice) → fl_chart reports -1.
    await tester.tapAt(pieRect.center);
    await tester.pumpAndSettle();

    // Selection cleared, hint restored, and no exception was thrown.
    expect(find.text(hint), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
  });

  testWidgets('legend tap also toggles selection without throwing',
      (tester) async {
    await _pumpReports(tester, _sampleData);

    const hint = 'Tap a slice to see details';
    // The legend row is an InkWell wrapping the category name.
    final legendFood = find.ancestor(
      of: find.text('Food'),
      matching: find.byType(InkWell),
    );

    await tester.tap(legendFood);
    await tester.pumpAndSettle();
    expect(find.text(hint), findsNothing);

    // Tapping the same legend row again deselects (detail panel 'Food' has no
    // InkWell ancestor, so this still resolves to the legend row only).
    await tester.tap(legendFood);
    await tester.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);
  });
}
