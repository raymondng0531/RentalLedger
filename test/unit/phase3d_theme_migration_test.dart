import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/app/theme/app_colors.dart';
import 'package:rental_ledger/app/theme/app_theme.dart';
import 'package:rental_ledger/core/widgets/activity_card.dart';
import 'package:rental_ledger/features/expenses/domain/entities/bill_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/category_entity.dart';
import 'package:rental_ledger/features/expenses/presentation/providers/expense_provider.dart';
import 'package:rental_ledger/features/history/presentation/pages/bill_history_page.dart';
import 'package:rental_ledger/features/history/presentation/pages/history_page.dart';
import 'package:rental_ledger/features/history/presentation/providers/bill_history_provider.dart';
import 'package:rental_ledger/features/history/presentation/providers/history_provider.dart';
import 'package:rental_ledger/features/history/presentation/utils/bill_history.dart';
import 'package:rental_ledger/features/history/presentation/widgets/filter_widgets.dart';
import 'package:rental_ledger/features/history/presentation/widgets/history_month_header.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';
import 'package:rental_ledger/features/reports/presentation/pages/reports_page.dart';
import 'package:rental_ledger/features/reports/presentation/providers/reports_provider.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Phase 3D — History + Reports.
///
/// Four kinds of claim are proved here:
///
/// 1. **Parity.** Every colour Phase 3D replaced resolves in light mode to the
///    exact ARGB value V1.0 shipped — asserted against the legacy `AppTheme`
///    constant the old call site actually read, so a later palette edit cannot
///    silently re-colour the shipped light theme.
/// 2. **Dark legibility.** The same widgets, pumped over `AppTheme.darkTheme`,
///    clear WCAG AA against what they really sit on — including composited
///    fills (a chip's 16-alpha wash over the card), not just the raw token.
/// 3. **Chart integrity.** The donut's slice colours are the *stored*
///    Firestore values, byte for byte, in BOTH modes — dark mode adapts the
///    palette fallback and nothing else. That is the Rule 5 guarantee.
/// 4. **Deliberate non-migrations.** The colours Phase 3D chose to LEAVE are
///    pinned too: the pie's inert `Colors.white` titleStyle, and the fact that
///    a selected slice dims by ALPHA rather than by becoming another colour.
///
/// Where a shipped V1.0 pairing falls short of AA, the test asserts the
/// *shortfall itself* rather than quietly lowering the bar: light mode is
/// frozen this phase, so the honest claim is "unchanged, and dark is no
/// worse". Those ratios are surfaced in the Phase 3D audit as recommendations.

// ── Contrast helpers ────────────────────────────────────────────────

/// WCAG contrast ratio: `(lighter + 0.05) / (darker + 0.05)`.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

/// What a translucent fill actually looks like once painted over its ground.
///
/// `computeLuminance()` ignores alpha, so a raw `withAlpha(16)` colour would
/// report the contrast of the *opaque* hue and flatter every chip on the page.
Color _over(Color fill, Color ground) => Color.alphaBlend(fill, ground);

const double _aa = 4.5;

/// WCAG's bar for a graphical object (a chart slice, a bar, an icon glyph)
/// rather than text — the standard the category palette is held to.
const double _nonText = 3.0;

// ── Pump helpers ────────────────────────────────────────────────────

/// A page that owns its own `Scaffold` and provider scope.
///
/// Sized tall so lazily-built list sections mount every row, matching the
/// convention the responsive width tests use for these same pages.
Future<void> _pumpPage(
  WidgetTester tester,
  Widget app, {
  Size size = const Size(800, 2400),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pump(); // Stream.value emits on the next microtask → data state.
  await tester.pumpAndSettle(); // Entrance animations, legend stagger, theme fade.
}

/// A leaf widget pumped on its own, over one theme.
Future<void> _pump(
  WidgetTester tester,
  Widget child,
  ThemeData theme, {
  Size size = const Size(420, 600),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Fixtures ────────────────────────────────────────────────────────

const _categories = <CategoryEntity>[
  CategoryEntity(categoryId: 'food', name: 'Food', icon: 'restaurant'),
  CategoryEntity(
    categoryId: 'utilities',
    name: 'Utilities',
    icon: 'bolt',
    // The shipped stored colour, verbatim.
    color: 0xFFF97316,
  ),
];

final _members = <HouseMemberEntity>[
  HouseMemberEntity(
    memberId: 'm1',
    houseId: 'h1',
    userId: 'u1',
    role: 'Treasurer',
    joinedAt: DateTime(2026),
    displayName: 'Bob',
  ),
];

final _now = DateTime(2026, 9, 10);

/// One event per visual role History can render, so every branch of the tile's
/// icon / status-chip / amount-style switch is exercised on screen.
List<HistoryEvent> _historyEvents() => [
  HistoryEvent(
    id: 'dep',
    type: HistoryEventType.deposit,
    title: 'Monthly Deposit',
    amount: 300,
    date: _now,
    userId: 'u1',
    paidByUserId: 'u1',
  ),
  HistoryEvent(
    id: 'dp',
    type: HistoryEventType.directPayment,
    title: 'Plumber',
    amount: -80,
    date: _now.subtract(const Duration(days: 1)),
    userId: 'u1',
    paymentMethod: 'Cash',
  ),
  HistoryEvent(
    id: 'bill',
    type: HistoryEventType.billCreated,
    refId: 'b1',
    title: 'Water Bill',
    amount: 60,
    date: _now.subtract(const Duration(days: 2)),
    categoryId: 'utilities',
    userId: 'u1',
  ),
  HistoryEvent(
    id: 'exp-sub',
    type: HistoryEventType.expenseSubmitted,
    refId: 'e1',
    title: 'Dish Soap',
    amount: 12,
    date: _now.subtract(const Duration(days: 3)),
    categoryId: 'food',
    status: 'pending',
    userId: 'u1',
    paymentSource: 'central',
  ),
  HistoryEvent(
    id: 'exp-app',
    type: HistoryEventType.expenseApproved,
    refId: 'e2',
    title: 'Rice Cooker',
    amount: 99,
    date: _now.subtract(const Duration(days: 4)),
    categoryId: 'food',
    status: 'approved',
    userId: 'u1',
    paymentSource: 'personal',
  ),
  HistoryEvent(
    id: 'exp-paid',
    type: HistoryEventType.expensePaid,
    refId: 'e3',
    title: 'Cleaning Supplies',
    amount: 45,
    date: _now.subtract(const Duration(days: 5)),
    categoryId: 'food',
    status: 'paid',
    userId: 'u1',
  ),
  HistoryEvent(
    id: 'exp-rej',
    type: HistoryEventType.expenseRejected,
    refId: 'e4',
    title: 'Video Game',
    amount: 200,
    date: _now.subtract(const Duration(days: 6)),
    categoryId: 'food',
    status: 'rejected',
    userId: 'u1',
  ),
  HistoryEvent(
    id: 'adj',
    type: HistoryEventType.adjustment,
    title: 'Rounding correction',
    amount: 5,
    date: _now.subtract(const Duration(days: 7)),
    userId: 'u1',
  ),
];

Widget _historyApp(ThemeData theme) => ProviderScope(
  overrides: [
    historyProvider.overrideWith((ref, key) => Stream.value(_historyEvents())),
    categoriesProvider.overrideWith((ref) async => _categories),
    // History resolves actor/payer names from ALL member records.
    allMembersStreamProvider.overrideWith((ref) => Stream.value(_members)),
  ],
  child: MaterialApp(
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const HistoryPage(),
  ),
);

/// Bill History: one bill in each derived status, plus an amountless reminder.
List<BillHistoryEntry> _billEntries() => buildBillHistoryEntries(
  bills: [
    BillEntity(
      billId: 'bill-util',
      houseId: 'h1',
      title: 'Electricity',
      amount: 120,
      dueDate: DateTime(2026, 8, 20),
      isPaid: true,
      createdAt: DateTime(2026),
    ),
    BillEntity(
      billId: 'bill-wifi',
      houseId: 'h1',
      title: 'Internet',
      amount: 150,
      dueDate: DateTime(2026, 12),
      createdAt: DateTime(2026),
    ),
    BillEntity(
      billId: 'bill-water',
      houseId: 'h1',
      title: 'Water',
      amount: 80,
      dueDate: DateTime(2026, 8),
      createdAt: DateTime(2026),
    ),
    BillEntity(
      billId: 'bill-gas',
      houseId: 'h1',
      // No amount: settles without writing a transaction, so it renders
      // "Reminder" rather than a fabricated RM 0.00.
      title: 'Gas reminder',
      dueDate: DateTime(2026, 12, 20),
      createdAt: DateTime(2026),
    ),
  ],
  events: [
    HistoryEvent(
      id: 'paid-1',
      type: HistoryEventType.billPaid,
      refId: 'bill-util',
      title: 'Electricity',
      amount: -120,
      date: DateTime(2026, 8, 6, 17, 3),
      userId: 'u1',
      paymentMethod: 'Bank Transfer',
      periodLabel: '2026-08',
    ),
  ],
  now: _now,
);

Widget _billHistoryApp(ThemeData theme) => ProviderScope(
  overrides: [
    billHistoryProvider.overrideWithValue(AsyncValue.data(_billEntries())),
    categoriesProvider.overrideWith((ref) async => _categories),
    allMembersStreamProvider.overrideWith((ref) => Stream.value(_members)),
  ],
  child: MaterialApp(
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const BillHistoryPage(),
  ),
);

// ── Reports fixtures ────────────────────────────────────────────────

/// Stored category colours, verbatim from `CategoryEntity`'s seeded defaults.
/// These are the values Rule 5 forbids dark mode from rewriting.
const _storedCategoryColors = <String, int>{
  'Rent': 0xFF2563EB,
  'Utilities': 0xFFF97316,
  'Food': 0xFF16A34A,
  'Household': 0xFF7C3AED,
  'Maintenance': 0xFFD97706,
  'Internet': 0xFF0891B2,
  'Other': 0xFF64748B,
};

ReportsData _reportsData({bool withUncolouredCategory = false}) => ReportsData(
  totalExpenses: 350,
  totalDeposits: 800,
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
  moneyOutBreakdown: const MoneyOutBreakdown(
    expenseReimbursements: 400,
    directPayments: 150,
    billPayments: 50,
  ),
  categoryBreakdown: [
    const CategorySpending(name: 'Food', amount: 100, color: 0xFF16A34A),
    const CategorySpending(name: 'Rent', amount: 200, color: 0xFF2563EB),
    const CategorySpending(name: 'Utilities', amount: 50, color: 0xFFF97316),
    // A category that stores no colour at all — the ONLY case dark mode is
    // allowed to re-resolve.
    if (withUncolouredCategory)
      const CategorySpending(name: 'Misc', amount: 25),
  ],
  monthlyTrend: const [
    MonthlyComparison(month: 'Aug', moneyIn: 800, moneyOut: 600),
  ],
);

Widget _reportsApp(ThemeData theme, {bool withUncolouredCategory = false}) =>
    ProviderScope(
      overrides: [
        reportsProvider.overrideWith(
          (ref) => Stream.value(
            _reportsData(withUncolouredCategory: withUncolouredCategory),
          ),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ReportsPage(),
      ),
    );

PieChartData _pie(WidgetTester tester) =>
    tester.widget<PieChart>(find.byType(PieChart)).data;

BarChartData _bars(WidgetTester tester) =>
    tester.widget<BarChart>(find.byType(BarChart)).data;

/// The legend row that carries [label] — a tappable swatch-plus-text entry.
///
/// A label can appear more than once on the page: "Money In" is both a
/// summary-box heading and a trend-legend entry, and a category name can be
/// both a donut legend row and an Insights card value. Only Rows whose FIRST
/// child is the swatch `Container` are a legend entry, which excludes the
/// summary row (its first child is an `Expanded`).
Finder _legendRowFor(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate(
    (w) => w is Row && w.children.isNotEmpty && w.children.first is Container,
  ),
);

/// The swatch colour of the legend row carrying [label].
Color _legendSwatch(WidgetTester tester, String label) {
  final rows = tester.widgetList<Row>(_legendRowFor(label)).toList();
  expect(rows, isNotEmpty, reason: 'no legend swatch found for "$label"');
  final dot = rows.first.children.first as Container;
  return (dot.decoration! as BoxDecoration).color!;
}

/// The `ActivityCard` rendering the row whose title is [title].
ActivityCard _cardFor(WidgetTester tester, String title) =>
    tester.widget<ActivityCard>(
      find.ancestor(of: find.text(title), matching: find.byType(ActivityCard)),
    );

Finder _chipsOn(String title) => find.descendant(
  of: find.ancestor(
    of: find.text(title),
    matching: find.byType(ActivityCard),
  ),
  matching: find.byType(ActivityChip),
);

/// The ink of the first chip on the card — i.e. its status chip.
Color _firstChipInk(WidgetTester tester, String title) =>
    tester.widget<ActivityChip>(_chipsOn(title).first).color;

void main() {
  // ═══════════════════════════════════════════════════════════════════
  // 1. Light-mode parity ledger
  // ═══════════════════════════════════════════════════════════════════

  group('light-mode parity — every replaced literal resolves to V1.0', () {
    // Each pair is (the token Phase 3D now reads, the AppTheme constant the
    // old call site read). Compared via toARGB32() because Color.== is
    // runtimeType-sensitive in this Flutter version: Colors.white is a
    // MaterialColor and would never compare equal to a plain Color token, even
    // at the same ARGB.
    final ledger = <String, (Color, Color)>{
      'primary': (AppColors.light.primary, AppTheme.primaryGreen),
      'success': (AppColors.light.success, AppTheme.successGreen),
      'error': (AppColors.light.error, AppTheme.errorRed),
      'warning': (AppColors.light.warning, AppTheme.warningOrange),
      'textPrimary': (AppColors.light.textPrimary, AppTheme.textPrimary),
      'textSecondary': (AppColors.light.textSecondary, AppTheme.textSecondary),
      'textHint': (AppColors.light.textHint, AppTheme.textHint),
      'divider': (AppColors.light.divider, AppTheme.dividerColor),
      'statusPending': (AppColors.light.statusPending, AppTheme.statusPending),
      'statusApproved': (
        AppColors.light.statusApproved,
        AppTheme.statusApproved,
      ),
      'statusDirectPayment': (
        AppColors.light.statusDirectPayment,
        AppTheme.statusDirectPayment,
      ),
    };

    ledger.forEach((name, pair) {
      test('$name is byte-identical to its legacy constant', () {
        expect(pair.$1.toARGB32(), pair.$2.toARGB32());
      });
    });

    test('surface / surfaceElevated are the shipped surfaceWhite', () {
      expect(
        AppColors.light.surface.toARGB32(),
        AppTheme.surfaceWhite.toARGB32(),
      );
      expect(
        AppColors.light.surfaceElevated.toARGB32(),
        AppTheme.surfaceWhite.toARGB32(),
      );
    });

    test('surfaceMuted is the shipped backgroundLight (FilterButton fill)', () {
      expect(
        AppColors.light.surfaceMuted.toARGB32(),
        AppTheme.backgroundLight.toARGB32(),
      );
    });

    test('onPrimary is white — the filter badge ink V1.0 shipped', () {
      expect(AppColors.light.onPrimary.toARGB32(), 0xFFFFFFFF);
    });

    test('categoryFallback is the shipped categoryFallbackHex', () {
      expect(
        AppColors.light.categoryFallback.toARGB32(),
        AppTheme.categoryFallbackHex,
      );
    });

    test('no light token drifted from the frozen V1.0 palette', () {
      // Pinned as literals so a palette edit is caught even if the legacy
      // constant were changed alongside it — these three carry the History and
      // Reports surfaces.
      expect(AppColors.light.primary.toARGB32(), 0xFF00897B);
      expect(AppColors.light.surfaceMuted.toARGB32(), 0xFFF5F5F5);
      expect(AppColors.light.error.toARGB32(), 0xFFDC3545);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 2. The filter sheet — Phase 3D's one consequential History fix
  // ═══════════════════════════════════════════════════════════════════

  group('filter sheet surface', () {
    /// Opens the real sheet through the real entry point and reads the surface
    /// `showModalBottomSheet` actually painted.
    Future<Color> openSheet(WidgetTester tester, ThemeData theme) async {
      await tester.binding.setSurfaceSize(const Size(500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFilterSheet(
                  context,
                  sections: [
                    const FilterOptionsSection(
                      label: 'Type',
                      group: FilterOptionGroup(
                        selected: {},
                        options: [FilterOption(value: 'a', label: 'Deposit')],
                      ),
                    ),
                  ],
                  onApply: (_) {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor!;
    }

    testWidgets('light mode paints the shipped white sheet', (tester) async {
      expect(
        (await openSheet(tester, AppTheme.lightTheme)).toARGB32(),
        AppTheme.surfaceWhite.toARGB32(),
      );
    });

    testWidgets('dark mode paints the elevated surface, not white', (
      tester,
    ) async {
      final fill = await openSheet(tester, AppTheme.darkTheme);
      expect(fill.toARGB32(), AppColors.dark.surfaceElevated.toARGB32());
      // The regression this pins: a hardcoded white overrides the dark
      // bottomSheetTheme and puts a white sheet on a dark app. SpringSheet
      // animates position and opacity only and paints no background of its
      // own, so this value IS the whole sheet surface.
      expect(fill.toARGB32(), isNot(0xFFFFFFFF));
    });

    testWidgets('the sheet content is readable against its own surface', (
      tester,
    ) async {
      await openSheet(tester, AppTheme.darkTheme);
      // A section label is the quietest ink in the sheet.
      final label = tester.widget<Text>(find.text('TYPE'));
      expect(
        _contrast(label.style!.color!, AppColors.dark.surfaceElevated),
        greaterThanOrEqualTo(_aa),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 3. Filter controls
  // ═══════════════════════════════════════════════════════════════════

  group('filter controls', () {
    final modes = <(ThemeData, AppColors)>[
      (AppTheme.lightTheme, AppColors.light),
      (AppTheme.darkTheme, AppColors.dark),
    ];

    Material fillOf<T extends Widget>(WidgetTester tester) => tester.widget<Material>(
      find.descendant(of: find.byType(T), matching: find.byType(Material)).first,
    );

    testWidgets('FilterButton fill and ink follow the theme', (tester) async {
      for (final (theme, colors) in modes) {
        await _pump(
          tester,
          FilterButton(activeCount: 0, onTap: () {}),
          theme,
          size: const Size(420, 300),
        );
        expect(
          fillOf<FilterButton>(tester).color!.toARGB32(),
          colors.surfaceMuted.toARGB32(),
        );

        // Active: the primary wash plus a badge in the on-primary ink.
        await _pump(
          tester,
          FilterButton(activeCount: 2, onTap: () {}),
          theme,
          size: const Size(420, 300),
        );
        expect(
          fillOf<FilterButton>(tester).color!.toARGB32(),
          colors.primary.withAlpha(12).toARGB32(),
        );
        expect(
          tester.widget<Text>(find.text('2')).style!.color!.toARGB32(),
          colors.onPrimary.toARGB32(),
        );
      }
    });

    testWidgets('the active-filter badge clears AA in dark mode', (
      tester,
    ) async {
      expect(
        _contrast(AppColors.dark.onPrimary, AppColors.dark.primary),
        greaterThanOrEqualTo(_aa),
        reason: 'the badge count must read on the dark primary fill',
      );
    });

    testWidgets('the shipped light badge shortfall is recorded, not widened', (
      tester,
    ) async {
      // White on `primaryGreen` measures 4.32:1 — V1.0's own value, 0.18 short
      // of AA, frozen this phase along with the rest of light mode. Pinned to
      // the measured figure so a future palette change is a deliberate one.
      final light = _contrast(AppColors.light.onPrimary, AppColors.light.primary);
      expect(light, closeTo(4.32, 0.02));
      expect(light, lessThan(_aa));
      expect(
        _contrast(AppColors.dark.onPrimary, AppColors.dark.primary),
        greaterThan(light),
      );
    });

    testWidgets('an unselected option tile is the sheet-surface well', (
      tester,
    ) async {
      for (final (theme, colors) in modes) {
        await _pump(
          tester,
          FilterSelectableOption(
            label: 'Deposit',
            selected: false,
            onTap: () {},
          ),
          theme,
          size: const Size(420, 300),
        );
        expect(
          fillOf<FilterSelectableOption>(tester).color!.toARGB32(),
          colors.surface.toARGB32(),
        );
        final label = tester.widget<Text>(find.text('Deposit'));
        expect(label.style!.color!.toARGB32(), colors.textPrimary.toARGB32());
        expect(
          _contrast(colors.textPrimary, colors.surface),
          greaterThanOrEqualTo(_aa),
        );
        // The unselected hairline is the divider token.
        final box = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(FilterSelectableOption),
                matching: find.byType(Container),
              )
              .first,
        );
        final border = (box.decoration! as BoxDecoration).border! as Border;
        expect(border.top.color.toARGB32(), colors.divider.toARGB32());
        expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      }
    });

    testWidgets('a selected option tile is the primary wash + primary ink', (
      tester,
    ) async {
      for (final (theme, colors) in modes) {
        await _pump(
          tester,
          FilterSelectableOption(
            label: 'Deposit',
            selected: true,
            onTap: () {},
          ),
          theme,
          size: const Size(420, 300),
        );
        expect(
          fillOf<FilterSelectableOption>(tester).color!.toARGB32(),
          colors.primary.withAlpha(12).toARGB32(),
        );
        expect(
          tester.widget<Text>(find.text('Deposit')).style!.color!.toARGB32(),
          colors.primary.toARGB32(),
        );
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      }
    });

    testWidgets('the selected tile ink clears AA on its own wash in dark mode', (
      tester,
    ) async {
      // The primary ink sits on its own 12-alpha wash, not on bare surface.
      final well = _over(
        AppColors.dark.primary.withAlpha(12),
        AppColors.dark.surface,
      );
      expect(
        _contrast(AppColors.dark.primary, well),
        greaterThanOrEqualTo(_aa),
      );
      // Light measures 4.07:1 on the same wash — V1.0's own shortfall.
      final lightWell = _over(
        AppColors.light.primary.withAlpha(12),
        AppColors.light.surface,
      );
      expect(
        _contrast(AppColors.light.primary, lightWell),
        closeTo(4.07, 0.02),
      );
    });

    testWidgets('SummaryChip edge and FilterSection label follow the theme', (
      tester,
    ) async {
      for (final (theme, colors) in modes) {
        await _pump(
          tester,
          Column(
            children: [
              SummaryChip(label: 'Deposit', onDeleted: () {}),
              const FilterSection(label: 'Type', child: SizedBox()),
            ],
          ),
          theme,
          size: const Size(420, 400),
        );
        expect(
          tester.widget<Chip>(find.byType(Chip)).side!.color.toARGB32(),
          colors.primary.withAlpha(60).toARGB32(),
        );
        expect(
          tester.widget<Text>(find.text('TYPE')).style!.color!.toARGB32(),
          colors.textSecondary.toARGB32(),
        );
      }
    });

    testWidgets('the month header is themed in both modes', (tester) async {
      for (final (theme, colors) in modes) {
        await _pump(
          tester,
          const HistoryMonthHeader(label: 'AUGUST 2026'),
          theme,
          size: const Size(420, 300),
        );
        expect(
          tester.widget<Text>(find.text('AUGUST 2026')).style!.color!.toARGB32(),
          colors.textSecondary.toARGB32(),
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 4. History — status colours, at page level
  // ═══════════════════════════════════════════════════════════════════

  group('History — status, amount and card colours', () {
    testWidgets('every event type resolves its icon to a status-role token', (
      tester,
    ) async {
      await _pumpPage(tester, _historyApp(AppTheme.darkTheme));
      const d = AppColors.dark;

      expect(
        _cardFor(tester, 'Monthly Deposit').iconColor.toARGB32(),
        d.success.toARGB32(),
      );
      expect(
        _cardFor(tester, 'Plumber').iconColor.toARGB32(),
        d.statusDirectPayment.toARGB32(),
      );
      expect(
        _cardFor(tester, 'Water Bill').iconColor.toARGB32(),
        d.statusPending.toARGB32(),
      );
      expect(
        _cardFor(tester, 'Dish Soap').iconColor.toARGB32(),
        d.statusPending.toARGB32(),
      );
      expect(
        _cardFor(tester, 'Rice Cooker').iconColor.toARGB32(),
        d.statusApproved.toARGB32(),
      );
      expect(
        _cardFor(tester, 'Cleaning Supplies').iconColor.toARGB32(),
        d.success.toARGB32(),
      );
      expect(
        _cardFor(tester, 'Video Game').iconColor.toARGB32(),
        d.error.toARGB32(),
      );
      expect(
        _cardFor(tester, 'Rounding correction').iconColor.toARGB32(),
        d.textSecondary.toARGB32(),
      );
    });

    testWidgets('the status chip agrees with its row icon', (tester) async {
      await _pumpPage(tester, _historyApp(AppTheme.darkTheme));
      for (final title in [
        'Monthly Deposit',
        'Dish Soap',
        'Rice Cooker',
        'Cleaning Supplies',
        'Video Game',
        'Rounding correction',
      ]) {
        expect(
          _firstChipInk(tester, title).toARGB32(),
          _cardFor(tester, title).iconColor.toARGB32(),
          reason: title,
        );
      }
      expect(find.text('Upcoming Bill'), findsOneWidget);
      expect(find.text('Direct Payment'), findsOneWidget);
      expect(find.text('Adjustment'), findsOneWidget);
    });

    testWidgets('money in is green, money out is red, milestones neutral', (
      tester,
    ) async {
      await _pumpPage(tester, _historyApp(AppTheme.darkTheme));
      const d = AppColors.dark;

      expect(
        _cardFor(tester, 'Monthly Deposit').amountColor!.toARGB32(),
        d.success.toARGB32(),
      );
      expect(_cardFor(tester, 'Monthly Deposit').amountSign, '+');
      expect(
        _cardFor(tester, 'Cleaning Supplies').amountColor!.toARGB32(),
        d.error.toARGB32(),
      );
      expect(_cardFor(tester, 'Cleaning Supplies').amountSign, '-');
      // A status milestone has not moved money: neutral ink, no sign.
      expect(
        _cardFor(tester, 'Rice Cooker').amountColor!.toARGB32(),
        d.textSecondary.toARGB32(),
      );
      expect(_cardFor(tester, 'Rice Cooker').amountSign, '');
    });

    testWidgets('the card fill is the muted surface in both modes', (
      tester,
    ) async {
      for (final (theme, colors) in [
        (AppTheme.lightTheme, AppColors.light),
        (AppTheme.darkTheme, AppColors.dark),
      ]) {
        await _pumpPage(tester, _historyApp(theme));
        expect(
          tester
              .widget<Card>(
                find
                    .descendant(
                      of: find.byType(ActivityCard),
                      matching: find.byType(Card),
                    )
                    .first,
              )
              .color!
              .toARGB32(),
          colors.surfaceMuted.toARGB32(),
        );
      }
    });

    testWidgets('dark chip inks are legible where V1.0 light mode was not', (
      tester,
    ) async {
      // ActivityCard paints a 16-alpha wash of the chip's own ink over the
      // card, so the ink sits on a tinted well, not on the bare card.
      //
      // The measured light-mode figures are the point of this table: V1.0
      // draws four of its six status chips far below AA (statusPending at
      // 1.89:1). Dark mode lifts every one of them clear of the bar, which is
      // the single biggest legibility gain Phase 3D delivers — and the reason
      // the chip colours were worth migrating at all.
      final lightChip = <String, (Color, double)>{
        'success': (AppColors.light.success, 2.70),
        'statusPending': (AppColors.light.statusPending, 1.89),
        'statusApproved': (AppColors.light.statusApproved, 2.69),
        'error': (AppColors.light.error, 3.81),
        'textSecondary': (AppColors.light.textSecondary, 4.12),
      };
      final darkChip = <String, Color>{
        'success': AppColors.dark.success,
        'statusPending': AppColors.dark.statusPending,
        'statusApproved': AppColors.dark.statusApproved,
        'error': AppColors.dark.error,
        'textSecondary': AppColors.dark.textSecondary,
      };

      for (final entry in lightChip.entries) {
        final lightInk = entry.value.$1;
        final darkInk = darkChip[entry.key]!;
        final light = _contrast(
          lightInk,
          _over(lightInk.withAlpha(16), AppColors.light.surfaceMuted),
        );
        final dark = _contrast(
          darkInk,
          _over(darkInk.withAlpha(16), AppColors.dark.surfaceMuted),
        );

        expect(light, closeTo(entry.value.$2, 0.02), reason: entry.key);
        expect(
          dark,
          greaterThanOrEqualTo(_aa),
          reason: 'the ${entry.key} chip must clear AA in dark mode',
        );
        if (light < _aa) {
          expect(
            dark,
            greaterThan(light),
            reason: 'dark mode must not inherit ${entry.key}\'s shortfall',
          );
        }
      }
    });

    testWidgets('the one dark chip shortfall is direct payment, recorded', (
      tester,
    ) async {
      // `statusDirectPayment` is the sole role dark mode draws LESS legibly
      // than light mode: V1.0 happened to get purple-on-grey right (5.25:1)
      // and the dark step lands at 4.25:1 — 0.25 short of AA. Reported as a
      // recommendation rather than fixed, because retuning the token would
      // change a palette value the earlier phases were approved with, and
      // Rule 5 forbids inventing colours without approval.
      final lightInk = AppColors.light.statusDirectPayment;
      final darkInk = AppColors.dark.statusDirectPayment;
      final light = _contrast(
        lightInk,
        _over(lightInk.withAlpha(16), AppColors.light.surfaceMuted),
      );
      final dark = _contrast(
        darkInk,
        _over(darkInk.withAlpha(16), AppColors.dark.surfaceMuted),
      );

      expect(light, closeTo(5.25, 0.02));
      expect(dark, closeTo(4.25, 0.02));
      expect(dark, lessThan(light));
      // It is still far above the non-text bar, so the icon and the chip's
      // tinted shape remain unambiguous even where the 11px label is marginal.
      expect(dark, greaterThan(_nonText));
    });

    testWidgets('every icon glyph clears the non-text bar on its tile', (
      tester,
    ) async {
      await _pumpPage(tester, _historyApp(AppTheme.darkTheme));
      // ActivityCard tints the 40x40 icon tile with a 22-alpha wash of the
      // glyph colour. An icon is a graphical object, so 3:1 is its bar —
      // which `statusDirectPayment` (4.12:1) clears even though its label
      // does not reach AA.
      final card = AppColors.dark.surfaceMuted;
      void legible(Color ink, String role) => expect(
        _contrast(ink, _over(ink.withAlpha(22), card)),
        greaterThanOrEqualTo(_nonText),
        reason: 'the $role icon must read on its own tile in dark mode',
      );

      legible(AppColors.dark.success, 'deposit / paid');
      legible(AppColors.dark.statusDirectPayment, 'direct payment');
      legible(AppColors.dark.statusPending, 'submitted / upcoming bill');
      legible(AppColors.dark.statusApproved, 'approved');
      legible(AppColors.dark.error, 'rejected');
      legible(AppColors.dark.textSecondary, 'adjustment');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 5. Bill History
  // ═══════════════════════════════════════════════════════════════════

  group('Bill History', () {
    testWidgets('paid / overdue / upcoming each take their status role', (
      tester,
    ) async {
      await _pumpPage(tester, _billHistoryApp(AppTheme.darkTheme));
      const d = AppColors.dark;

      expect(
        _cardFor(tester, 'Electricity').iconColor.toARGB32(),
        d.success.toARGB32(),
      );
      expect(
        _cardFor(tester, 'Water').iconColor.toARGB32(),
        d.error.toARGB32(),
      );
      expect(
        _cardFor(tester, 'Internet').iconColor.toARGB32(),
        d.statusPending.toARGB32(),
      );
      expect(
        _cardFor(tester, 'Gas reminder').iconColor.toARGB32(),
        d.statusPending.toARGB32(),
      );
    });

    testWidgets('the status chip agrees with the row icon', (tester) async {
      await _pumpPage(tester, _billHistoryApp(AppTheme.darkTheme));
      for (final title in ['Electricity', 'Water', 'Internet', 'Gas reminder']) {
        expect(
          _firstChipInk(tester, title).toARGB32(),
          _cardFor(tester, title).iconColor.toARGB32(),
          reason: title,
        );
      }
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('a bill amount is a magnitude — it keeps the theme ink', (
      tester,
    ) async {
      await _pumpPage(tester, _billHistoryApp(AppTheme.darkTheme));
      // Not money in or out, so no sign and no status hue — the theme default.
      expect(_cardFor(tester, 'Electricity').amountColor, isNull);
      expect(_cardFor(tester, 'Electricity').amountSign, '');
    });

    testWidgets('an amountless bill says Reminder, in the quiet ink', (
      tester,
    ) async {
      await _pumpPage(tester, _billHistoryApp(AppTheme.darkTheme));
      expect(find.text('Reminder'), findsOneWidget);
      expect(
        _cardFor(tester, 'Gas reminder').amountColor!.toARGB32(),
        AppColors.dark.textSecondary.toARGB32(),
      );
      // The neutral ink still clears AA on the card it is drawn on.
      expect(
        _contrast(AppColors.dark.textSecondary, AppColors.dark.surfaceMuted),
        greaterThanOrEqualTo(_aa),
      );
    });

    testWidgets('light mode renders the same rows with the light palette', (
      tester,
    ) async {
      await _pumpPage(tester, _billHistoryApp(AppTheme.lightTheme));
      const l = AppColors.light;
      expect(
        _cardFor(tester, 'Electricity').iconColor.toARGB32(),
        l.success.toARGB32(),
      );
      expect(
        _cardFor(tester, 'Water').iconColor.toARGB32(),
        l.error.toARGB32(),
      );
      expect(
        _cardFor(tester, 'Internet').iconColor.toARGB32(),
        l.statusPending.toARGB32(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 6. Reports — stored category colours are never rewritten (Rule 5)
  // ═══════════════════════════════════════════════════════════════════

  group('Reports — the donut', () {
    testWidgets('light mode draws the stored ARGB values verbatim', (
      tester,
    ) async {
      await _pumpPage(tester, _reportsApp(AppTheme.lightTheme));
      final s = _pie(tester).sections;
      expect(s[0].color.toARGB32(), 0xFF16A34A); // Food
      expect(s[1].color.toARGB32(), 0xFF2563EB); // Rent
      expect(s[2].color.toARGB32(), 0xFFF97316); // Utilities
    });

    testWidgets('dark mode draws the SAME stored ARGB values verbatim', (
      tester,
    ) async {
      await _pumpPage(tester, _reportsApp(AppTheme.darkTheme));
      final s = _pie(tester).sections;
      expect(s[0].color.toARGB32(), 0xFF16A34A);
      expect(s[1].color.toARGB32(), 0xFF2563EB);
      expect(s[2].color.toARGB32(), 0xFFF97316);
    });

    testWidgets('the legend repeats the stored colours in both modes', (
      tester,
    ) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await _pumpPage(tester, _reportsApp(theme));
        expect(_legendSwatch(tester, 'Food').toARGB32(), 0xFF16A34A);
        expect(_legendSwatch(tester, 'Rent').toARGB32(), 0xFF2563EB);
        expect(_legendSwatch(tester, 'Utilities').toARGB32(), 0xFFF97316);
      }
    });

    testWidgets('every stored default clears the non-text bar on dark', (
      tester,
    ) async {
      // Measured against the card each slice is drawn on. Dark mode is NOT a
      // regression for a single stored colour — its floor (Household, 3.04:1)
      // sits above light mode's own floor (Utilities, 2.80:1). That is why
      // dark mode leaves the stored hues alone rather than inventing new ones.
      for (final entry in _storedCategoryColors.entries) {
        expect(
          _contrast(Color(entry.value), AppColors.dark.surface),
          greaterThanOrEqualTo(_nonText),
          reason: '${entry.key} on the dark report card',
        );
      }
    });

    testWidgets('the shipped light-mode shortfall is unchanged, not widened', (
      tester,
    ) async {
      // V1.0 already draws Utilities below 3:1 on a white card. Light mode is
      // frozen this phase, so the honest assertion is "unchanged" — and the
      // important half of the claim is that DARK is better, not worse.
      final light = _contrast(const Color(0xFFF97316), AppColors.light.surface);
      final dark = _contrast(const Color(0xFFF97316), AppColors.dark.surface);
      expect(light, lessThan(_nonText));
      expect(dark, greaterThan(light));
      expect(dark, greaterThanOrEqualTo(_nonText));
    });

    testWidgets('only the UNSTORED fallback is theme-resolved', (tester) async {
      await _pumpPage(
        tester,
        _reportsApp(AppTheme.lightTheme, withUncolouredCategory: true),
      );
      final light = _pie(tester).sections.last.color.toARGB32();
      expect(light, AppColors.light.categoryFallback.toARGB32());
      expect(light, AppTheme.categoryFallbackHex);

      await _pumpPage(
        tester,
        _reportsApp(AppTheme.darkTheme, withUncolouredCategory: true),
      );
      final dark = _pie(tester).sections.last.color.toARGB32();
      expect(dark, AppColors.dark.categoryFallback.toARGB32());
      // The fallback is a palette value, not stored data, so unlike a stored
      // colour it IS allowed to differ between modes.
      expect(dark, isNot(light));
    });

    testWidgets('selecting a slice dims the others by ALPHA only', (
      tester,
    ) async {
      await _pumpPage(tester, _reportsApp(AppTheme.darkTheme));
      for (final s in _pie(tester).sections) {
        expect(s.color.a, 1.0, reason: 'nothing selected: full strength');
      }

      // Scoped to the legend row: "Rent" is also the fixture's
      // `highestCategoryName`, so it appears in an Insights card too.
      await tester.tap(_legendRowFor('Rent'));
      await tester.pumpAndSettle();

      final s = _pie(tester).sections;
      // The selected slice keeps the stored colour exactly.
      expect(s[1].color.toARGB32(), 0xFF2563EB);
      expect(s[1].color.a, 1.0);
      // The others are the SAME stored hue at reduced alpha — never a
      // different colour, so the category stays recognisable in both modes.
      expect(s[0].color.withAlpha(255).toARGB32(), 0xFF16A34A);
      expect(s[2].color.withAlpha(255).toARGB32(), 0xFFF97316);
      expect(s[0].color.a, lessThan(1.0));
      expect(s[2].color.a, lessThan(1.0));
    });

    testWidgets('the pie titleStyle is inert — the title is empty', (
      tester,
    ) async {
      // Pins the deliberate non-migration. `Colors.white` here paints nothing
      // because there is no title text to paint. If a future change gives a
      // slice a real label, this fails and the missing "ink on a slice" token
      // has to be designed rather than inherited.
      await _pumpPage(tester, _reportsApp(AppTheme.darkTheme));
      for (final s in _pie(tester).sections) {
        expect(s.title, isEmpty);
        expect(s.titleStyle!.color!.toARGB32(), 0xFFFFFFFF);
      }
    });

    testWidgets('the donut hint is themed and readable in dark mode', (
      tester,
    ) async {
      await _pumpPage(tester, _reportsApp(AppTheme.darkTheme));
      expect(
        tester
            .widget<Text>(find.text('Tap a slice to see details'))
            .style!
            .color!
            .toARGB32(),
        AppColors.dark.textHint.toARGB32(),
      );
      expect(
        _contrast(AppColors.dark.textHint, AppColors.dark.surface),
        greaterThan(_aa),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 7. Reports — chart chrome: bars, legend, axes, grid, tooltip
  // ═══════════════════════════════════════════════════════════════════

  group('Reports — chart chrome', () {
    final modes = <(ThemeData, AppColors)>[
      (AppTheme.lightTheme, AppColors.light),
      (AppTheme.darkTheme, AppColors.dark),
    ];

    testWidgets('the trend bars use the success/error roles in both modes', (
      tester,
    ) async {
      for (final (theme, colors) in modes) {
        await _pumpPage(tester, _reportsApp(theme));
        final rods = _bars(tester).barGroups.first.barRods;
        expect(rods[0].color!.toARGB32(), colors.success.toARGB32());
        expect(rods[1].color!.toARGB32(), colors.error.toARGB32());
      }
    });

    testWidgets('the trend legend dots match their bars', (tester) async {
      await _pumpPage(tester, _reportsApp(AppTheme.darkTheme));
      expect(
        _legendSwatch(tester, 'Money In').toARGB32(),
        AppColors.dark.success.toARGB32(),
      );
      expect(
        _legendSwatch(tester, 'Money Out').toARGB32(),
        AppColors.dark.error.toARGB32(),
      );
    });

    testWidgets('the gridline is the divider token', (tester) async {
      for (final (theme, colors) in modes) {
        await _pumpPage(tester, _reportsApp(theme));
        final line = _bars(tester).gridData.getDrawingHorizontalLine(1);
        expect(line.color!.toARGB32(), colors.divider.toARGB32());
      }
    });

    testWidgets('both axis label inks come from the palette', (tester) async {
      await _pumpPage(tester, _reportsApp(AppTheme.darkTheme));
      final titles = _bars(tester).titlesData;
      TitleMeta metaFor(double min, double max, AxisSide side) => TitleMeta(
        min: min,
        max: max,
        parentAxisSize: 200,
        axisPosition: 0,
        appliedInterval: 200,
        sideTitles: const SideTitles(showTitles: true),
        formattedValue: '200',
        axisSide: side,
        rotationQuarterTurns: 0,
      );

      // The left axis labels every interval EXCEPT the top of the range.
      final leftWidget = titles.leftTitles.sideTitles.getTitlesWidget(
        200,
        metaFor(0, 1000, AxisSide.left),
      );
      // The bottom axis labels each month by index.
      final bottomWidget = titles.bottomTitles.sideTitles.getTitlesWidget(
        0,
        metaFor(0, 0, AxisSide.bottom),
      );

      for (final widget in [leftWidget, bottomWidget]) {
        await _pump(
          tester,
          widget,
          AppTheme.darkTheme,
          size: const Size(300, 200),
        );
        final text = tester.widget<Text>(find.byType(Text));
        expect(
          text.style!.color!.toARGB32(),
          AppColors.dark.textSecondary.toARGB32(),
        );
      }

      // The ink clears AA on the card it is drawn on.
      expect(
        _contrast(AppColors.dark.textSecondary, AppColors.dark.surface),
        greaterThanOrEqualTo(_aa),
      );
    });

    testWidgets(
      'the tooltip fill is the elevated surface, outlined by the divider',
      (tester) async {
        for (final (theme, colors) in modes) {
          await _pumpPage(tester, _reportsApp(theme));
          final data = _bars(tester).barTouchData.touchTooltipData;
          expect(
            data.getTooltipColor(BarChartGroupData(x: 0)).toARGB32(),
            colors.surfaceElevated.toARGB32(),
          );
          expect(data.tooltipBorder.color.toARGB32(), colors.divider.toARGB32());
        }
      },
    );

    testWidgets('the dark tooltip ink is legible on the tooltip', (
      tester,
    ) async {
      for (final ink in [
        AppColors.dark.textPrimary,
        AppColors.dark.success,
        AppColors.dark.error,
      ]) {
        expect(
          _contrast(ink, AppColors.dark.surfaceElevated),
          greaterThanOrEqualTo(_aa),
        );
      }
      // Dark separates the tooltip from its card by 1.11:1 plus the hairline;
      // light gets 1.00:1 and relies on the hairline alone.
      expect(
        _contrast(AppColors.dark.surfaceElevated, AppColors.dark.surface),
        greaterThan(
          _contrast(AppColors.light.surfaceElevated, AppColors.light.surface),
        ),
      );
    });

    testWidgets('the shipped light tooltip shortfall is recorded, not widened', (
      tester,
    ) async {
      // The tooltip's green "Money In" line measures 3.13:1 on V1.0's white
      // tooltip — below AA, and the shipped value. Dark draws the same line at
      // 8.14:1. The red line is the one that already passed (4.53:1 light,
      // 5.65:1 dark).
      expect(
        _contrast(AppColors.light.success, AppColors.light.surfaceElevated),
        closeTo(3.13, 0.02),
      );
      expect(
        _contrast(AppColors.light.success, AppColors.light.surfaceElevated),
        lessThan(_aa),
      );
      expect(
        _contrast(AppColors.light.error, AppColors.light.surfaceElevated),
        greaterThanOrEqualTo(_aa),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 8. Reports — "Where the Money Goes"
  // ═══════════════════════════════════════════════════════════════════

  group('Reports — money-out breakdown', () {
    final modes = <(ThemeData, AppColors)>[
      (AppTheme.lightTheme, AppColors.light),
      (AppTheme.darkTheme, AppColors.dark),
    ];

    testWidgets('each bucket takes its semantic role in both modes', (
      tester,
    ) async {
      for (final (theme, colors) in modes) {
        await _pumpPage(tester, _reportsApp(theme));
        expect(
          _legendSwatch(tester, 'Expense reimbursements').toARGB32(),
          colors.statusApproved.toARGB32(),
        );
        expect(
          _legendSwatch(tester, 'Direct payments').toARGB32(),
          colors.warning.toARGB32(),
        );
        expect(
          _legendSwatch(tester, 'Bill payments').toARGB32(),
          colors.primary.toARGB32(),
        );
        // The zero buckets render no row at all.
        expect(find.text('Adjustments'), findsNothing);
        expect(find.text('Other'), findsNothing);
      }
    });

    testWidgets('every rendered segment clears the non-text bar on dark', (
      tester,
    ) async {
      await _pumpPage(tester, _reportsApp(AppTheme.darkTheme));
      for (final ink in [
        AppColors.dark.statusApproved,
        AppColors.dark.warning,
        AppColors.dark.primary,
      ]) {
        expect(
          _contrast(ink, AppColors.dark.surface),
          greaterThanOrEqualTo(_nonText),
        );
      }
    });

    testWidgets('the light-mode warning floor is recorded, not widened', (
      tester,
    ) async {
      // `warningOrange` as a stacked-bar segment on a white card measures
      // ~1.63:1 — V1.0's own chart floor. Frozen this phase; dark mode is
      // strictly better, which is the claim worth pinning.
      final light = _contrast(AppColors.light.warning, AppColors.light.surface);
      expect(light, lessThan(_nonText));
      expect(
        _contrast(AppColors.dark.warning, AppColors.dark.surface),
        greaterThan(light),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 9. Reports — supporting text
  // ═══════════════════════════════════════════════════════════════════

  group('Reports — supporting text', () {
    testWidgets('a summary-box label takes the secondary ink in both modes', (
      tester,
    ) async {
      for (final (theme, colors) in [
        (AppTheme.lightTheme, AppColors.light),
        (AppTheme.darkTheme, AppColors.dark),
      ]) {
        await _pumpPage(tester, _reportsApp(theme));
        // "Current Balance" is unique to the summary row, unlike "Money In".
        expect(
          tester
              .widget<Text>(find.text('Current Balance'))
              .style!
              .color!
              .toARGB32(),
          colors.textSecondary.toARGB32(),
        );
      }
    });

    testWidgets('the dark supporting inks beat their light-mode twins', (
      tester,
    ) async {
      // textHint on the card: 5.01:1 dark vs 2.68:1 light. The shortfall is
      // light mode's and light mode is frozen, so the claim is that dark mode
      // is strictly more legible — not that the shipped value was correct.
      final darkHint = _contrast(
        AppColors.dark.textHint,
        AppColors.dark.surface,
      );
      final lightHint = _contrast(
        AppColors.light.textHint,
        AppColors.light.surface,
      );
      expect(darkHint, greaterThan(lightHint));
      expect(darkHint, greaterThan(_aa));
    });

    testWidgets('every paired token clears AA in dark mode', (tester) async {
      // A guard on the palette itself. Note the claim is NOT "dark beats
      // light" for every pair: `textPrimary` is 16.86:1 on white and 14.18:1
      // on the dark surface, both far above the bar, and demanding an
      // improvement on 16.86:1 would be a rule about nothing. The claim that
      // matters is that dark mode is legible, on its own ground.
      final darkPairs = <String, (Color, Color)>{
        'textPrimary': (AppColors.dark.textPrimary, AppColors.dark.surface),
        'textSecondary': (
          AppColors.dark.textSecondary,
          AppColors.dark.surface,
        ),
        'primary': (AppColors.dark.primary, AppColors.dark.surface),
        'error': (AppColors.dark.error, AppColors.dark.surface),
      };
      darkPairs.forEach((name, pair) {
        expect(
          _contrast(pair.$1, pair.$2),
          greaterThanOrEqualTo(_aa),
          reason: '$name must clear AA on the dark card',
        );
      });

      // Where V1.0 already fell short, dark mode must rescue it rather than
      // inherit it — the `textHint` the donut's hint line uses is the case in
      // point: 2.68:1 light, 4.52:1 dark.
      final lightPairs = <String, (Color, Color)>{
        'textHint': (AppColors.light.textHint, AppColors.light.surface),
      };
      lightPairs.forEach((name, light) {
        expect(
          _contrast(light.$1, light.$2),
          lessThan(_aa),
          reason: '$name is a known V1.0 shortfall — if this now passes, '
              'the audit note is stale and should be updated',
        );
      });
    });
  });
}
