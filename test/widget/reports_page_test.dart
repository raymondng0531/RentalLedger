import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/reports/presentation/pages/reports_page.dart';
import 'package:rental_ledger/features/reports/presentation/providers/reports_provider.dart';

Widget _buildReports(ReportsData data) {
  return ProviderScope(
    overrides: [
      reportsProvider.overrideWith((ref) => Stream.value(data)),
    ],
    child: const MaterialApp(home: ReportsPage()),
  );
}

const ReportsData _sampleData = ReportsData(
  totalExpenses: 350,
  totalDeposits: 800,
  // Money In − Money Out = Balance (800 − 649 = 151), mirroring a real
  // household where Money Out includes direct/bill payments beyond claims.
  moneyIn: 800,
  moneyOut: 649,
  balance: 151,
  highestCategoryName: 'Rent',
  highestCategoryAmount: 200,
  largestExpense: 150,
  averageMonthlyExpense: 116.67,
  avgExpenseClaim: 175,
  pendingReimbursements: 0,
  avgDeposit: 400,
  largestDeposit: 600,
  billsPaid: 1,
  billsPending: 2,
  categoryBreakdown: [
    // Slices sweep clockwise from 0° (east): Food ≈ 0°–103°, Rent ≈
    // 103°–309°, Utilities ≈ 309°–360°.
    CategorySpending(name: 'Food', amount: 100, color: 0xFF16A34A),
    CategorySpending(name: 'Rent', amount: 200, color: 0xFF2563EB),
    CategorySpending(name: 'Utilities', amount: 50, color: 0xFFF97316),
  ],
  monthlyTrend: [
    MonthlyComparison(month: 'Aug', moneyIn: 800, moneyOut: 649),
  ],
);

Future<void> _pumpReports(WidgetTester tester, ReportsData data) async {
  // The page is a ListView; give the viewport enough height that every
  // section (including the Monthly Trend card) actually gets built.
  tester.view.physicalSize = const Size(800, 2000);
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
    // The old, misleading labels are gone.
    expect(find.text('Total Expenses'), findsNothing);
    expect(find.text('Total Deposits'), findsNothing);
    expect(find.text('Net Flow'), findsNothing);
  });

  testWidgets('insights show the five analytics cards', (tester) async {
    await _pumpReports(tester, _sampleData);

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

    // The low-value statistics were removed.
    expect(find.text('Average Expense Claim'), findsNothing);
    expect(find.text('Total Bills Paid'), findsNothing);
    expect(find.text('Total Bills Pending'), findsNothing);
    expect(find.text('Average Deposit'), findsNothing);
    expect(find.text('Largest Deposit'), findsNothing);
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
    await tester.tapAt(_pointOnSlice(pieRect, 50, 50));
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
