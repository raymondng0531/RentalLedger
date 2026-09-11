import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/expenses/domain/entities/category_entity.dart';
import 'package:rental_ledger/features/history/presentation/utils/filter_periods.dart';
import 'package:rental_ledger/features/history/presentation/widgets/filter_widgets.dart';

/// Characterisation cover for the shared filter UI.
///
/// These widgets were private to `history_page.dart` and had NO test. They were
/// then lifted into `filter_widgets.dart` so Bill History could reuse them —
/// and an untested behaviour-preserving refactor is exactly the kind that
/// silently drifts. These tests pin what History's sheet actually did, so the
/// extraction is checkable rather than merely asserted:
///
/// * the sheet renders the sections it is handed, in the order it is handed
///   them (History passes Type, Period, Category, Status);
/// * a multi-select section (Type) toggles, and "All" clears it;
/// * a single-select section (Status) REPLACES and never toggles off — the
///   original Status tiles could not be deselected by tapping them again;
/// * Reset clears every section at once;
/// * Apply reports the choices back keyed by section label.
///
/// If a future change to the sheet makes one of these fail, it has changed
/// History's behaviour, not just Bill History's.

// ── Fixtures ────────────────────────────────────────────────────────

const _categories = <CategoryEntity>[
  CategoryEntity(categoryId: 'food', name: 'Food', icon: 'restaurant'),
  CategoryEntity(categoryId: 'utility', name: 'Utilities', icon: 'bolt'),
];

/// History's four sections, in History's order.
List<FilterSectionSpec> _historySections({
  Set<String> types = const {},
  String? category,
  String? status,
  String? preset,
  DateTimeRange? range,
}) {
  return [
    FilterOptionsSection(
      label: 'Type',
      group: FilterOptionGroup(
        multiSelect: true,
        selected: types,
        options: const [
          FilterOption(value: 'deposit', label: 'Deposit'),
          FilterOption(value: 'bill', label: 'Bill'),
          FilterOption(value: 'adjustment', label: 'Adjustment'),
        ],
      ),
    ),
    FilterPeriodSection(preset: preset, range: range),
    FilterCategorySection(category: category, categories: _categories),
    FilterOptionsSection(
      label: 'Status',
      group: FilterOptionGroup(
        selected: {if (status != null) status},
        options: const [
          FilterOption(value: 'pending', label: 'Pending'),
          FilterOption(value: 'approved', label: 'Approved'),
          FilterOption(value: 'paid', label: 'Paid'),
          FilterOption(value: 'rejected', label: 'Rejected'),
        ],
      ),
    ),
  ];
}

/// A pumped sheet, plus whatever its Apply last reported.
class _Sheet {
  _Sheet(this._applied);

  final List<FilterSheetResult> _applied;

  /// `null` until Apply is pressed.
  FilterSheetResult? get result => _applied.isEmpty ? null : _applied.last;
}

Future<_Sheet> _pumpSheet(
  WidgetTester tester,
  List<FilterSectionSpec> sections,
) async {
  final applied = <FilterSheetResult>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: FilterSheet(sections: sections, onApply: applied.add),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Sheet(applied);
}

/// The [FilterSection] whose heading is [label].
Finder _section(String label) =>
    find.byWidgetPredicate((w) => w is FilterSection && w.label == label);

/// The option tile labelled [label] INSIDE the [section] — the sheet renders
/// several tiles called "All" (Type, Period, Status each have one), so an
/// unscoped finder is ambiguous.
Finder _option(String section, String label) => find.descendant(
  of: _section(section),
  matching: find.widgetWithText(FilterSelectableOption, label),
);

/// Taps the option tile labelled [label] inside [section].
Future<void> _tapOption(
  WidgetTester tester,
  String section,
  String label,
) async {
  final finder = _option(section, label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapApply(WidgetTester tester) async {
  await tester.tap(find.text('Apply'));
  await tester.pumpAndSettle();
}

/// Whether the tile labelled [label] inside [section] renders as selected.
bool _isSelected(WidgetTester tester, String section, String label) => tester
    .widget<FilterSelectableOption>(_option(section, label))
    .selected;

/// Section headings, in render order.
List<String> _sectionOrder(WidgetTester tester) => tester
    .widgetList<FilterSection>(find.byType(FilterSection))
    .map((s) => s.label)
    .toList();

void main() {
  group('FilterButton', () {
    testWidgets('reads "Filters" and carries no badge when nothing is active', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FilterButton(activeCount: 0, onTap: () {})),
        ),
      );

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows the active-filter count as a badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FilterButton(activeCount: 3, onTap: () {})),
        ),
      );

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('invokes onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterButton(activeCount: 0, onTap: () => taps++),
          ),
        ),
      );

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });
  });

  group('SummaryChip', () {
    testWidgets('renders its label and reports deletion', (tester) async {
      var deleted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SummaryChip(label: 'Deposit', onDeleted: () => deleted++),
          ),
        ),
      );

      expect(find.text('Deposit'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(deleted, 1);
    });
  });

  group('FilterSheet — structure', () {
    testWidgets('renders the sections in the order it is given them', (
      tester,
    ) async {
      await _pumpSheet(tester, _historySections());

      // History's order is Type → Period → Category → Status. It is the
      // caller's order, not something the sheet decides.
      expect(_sectionOrder(tester), ['Type', 'Period', 'Category', 'Status']);
    });

    testWidgets('renders an "All" tile for every section', (tester) async {
      await _pumpSheet(tester, _historySections());

      // Type, Period and Status each carry their own All.
      for (final section in ['Type', 'Period', 'Status']) {
        expect(_option(section, 'All'), findsOneWidget, reason: section);
      }
    });

    testWidgets('renders every option of every section', (tester) async {
      await _pumpSheet(tester, _historySections());

      for (final label in ['Deposit', 'Bill', 'Adjustment']) {
        expect(_option('Type', label), findsOneWidget, reason: label);
      }
      for (final label in ['Pending', 'Approved', 'Paid', 'Rejected']) {
        expect(_option('Status', label), findsOneWidget, reason: label);
      }
    });

    testWidgets('renders the period presets plus a custom-range option', (
      tester,
    ) async {
      await _pumpSheet(tester, _historySections());

      for (final i in [0, 1, 2, 3, 4, 5, 6]) {
        expect(
          _option('Period', FilterPeriods.labels[i]),
          findsOneWidget,
          reason: FilterPeriods.labels[i],
        );
      }
      expect(_option('Period', 'Custom Range'), findsOneWidget);
    });

    testWidgets('the category dropdown defaults to All Categories', (
      tester,
    ) async {
      await _pumpSheet(tester, _historySections());

      expect(find.text('All Categories'), findsWidgets);
    });

    testWidgets('shows an existing selection as selected', (tester) async {
      await _pumpSheet(
        tester,
        _historySections(types: {'bill'}, status: 'paid', preset: '30d'),
      );

      expect(_isSelected(tester, 'Type', 'Bill'), isTrue);
      expect(_isSelected(tester, 'Type', 'Deposit'), isFalse);
      expect(_isSelected(tester, 'Status', 'Paid'), isTrue);
      expect(_isSelected(tester, 'Status', 'Pending'), isFalse);
      expect(_isSelected(tester, 'Period', 'Last 30 Days'), isTrue);
      expect(_isSelected(tester, 'Period', 'Today'), isFalse);
    });

    testWidgets('leaves "All" selected when nothing is chosen', (tester) async {
      await _pumpSheet(tester, _historySections());

      expect(_isSelected(tester, 'Type', 'All'), isTrue);
      expect(_isSelected(tester, 'Status', 'All'), isTrue);
      expect(_isSelected(tester, 'Period', 'All'), isTrue);
    });
  });

  group('FilterSheet — selection semantics', () {
    testWidgets('nothing is reported until Apply is pressed', (tester) async {
      final sheet = await _pumpSheet(tester, _historySections());

      await _tapOption(tester, 'Type', 'Deposit');

      expect(sheet.result, isNull);
    });

    testWidgets('a multi-select section reports every chosen value on Apply', (
      tester,
    ) async {
      final sheet = await _pumpSheet(tester, _historySections());

      await _tapOption(tester, 'Type', 'Deposit');
      await _tapOption(tester, 'Type', 'Adjustment');
      await _tapApply(tester);

      expect(sheet.result!.select('Type'), {'deposit', 'adjustment'});
    });

    testWidgets('tapping a chosen multi-select option again removes it', (
      tester,
    ) async {
      final sheet = await _pumpSheet(tester, _historySections());

      await _tapOption(tester, 'Type', 'Deposit');
      await _tapOption(tester, 'Type', 'Deposit');
      await _tapApply(tester);

      expect(sheet.result!.select('Type'), isEmpty);
    });

    testWidgets('"All" clears a multi-select section', (tester) async {
      final sheet = await _pumpSheet(
        tester,
        _historySections(types: {'deposit', 'bill'}),
      );

      await _tapOption(tester, 'Type', 'All');
      await _tapApply(tester);

      expect(sheet.result!.select('Type'), isEmpty);
    });

    testWidgets('a single-select section REPLACES the previous choice', (
      tester,
    ) async {
      final sheet = await _pumpSheet(tester, _historySections());

      await _tapOption(tester, 'Status', 'Pending');
      await _tapOption(tester, 'Status', 'Rejected');
      await _tapApply(tester);

      expect(sheet.result!.single('Status'), 'rejected');
    });

    testWidgets(
      'a single-select choice is never toggled off by tapping it again',
      (tester) async {
        // The original Status tiles replaced rather than toggled: once a status
        // was chosen, tapping it again left it chosen. "All" is the only way
        // back to no status filter.
        final sheet = await _pumpSheet(tester, _historySections());

        await _tapOption(tester, 'Status', 'Paid');
        await _tapOption(tester, 'Status', 'Paid');
        await _tapApply(tester);

        expect(sheet.result!.single('Status'), 'paid');
      },
    );

    testWidgets('"All" clears a single-select section', (tester) async {
      final sheet = await _pumpSheet(
        tester,
        _historySections(status: 'paid'),
      );

      await _tapOption(tester, 'Status', 'All');
      await _tapApply(tester);

      expect(sheet.result!.single('Status'), isNull);
    });

    testWidgets('choosing a period preset replaces the previous preset', (
      tester,
    ) async {
      final sheet = await _pumpSheet(
        tester,
        _historySections(preset: '30d'),
      );

      await _tapOption(tester, 'Period', 'Today');
      await _tapApply(tester);

      expect(sheet.result!.preset, 'today');
    });

    testWidgets('choosing a period preset clears a custom range', (
      tester,
    ) async {
      final sheet = await _pumpSheet(
        tester,
        _historySections(
          range: DateTimeRange(
            start: DateTime(2026, 3, 15),
            end: DateTime(2026, 4, 20),
          ),
        ),
      );

      await _tapOption(tester, 'Period', 'Today');
      await _tapApply(tester);

      expect(sheet.result!.preset, 'today');
      expect(sheet.result!.range, isNull);
    });

    testWidgets('an untouched sheet applies as "everything, unfiltered"', (
      tester,
    ) async {
      final sheet = await _pumpSheet(tester, _historySections());

      await _tapApply(tester);

      final result = sheet.result!;
      expect(result.select('Type'), isEmpty);
      expect(result.single('Status'), isNull);
      expect(result.category, isNull);
      expect(result.preset, isNull);
      expect(result.range, isNull);
    });

    testWidgets('the result is a copy, not the sheet\'s live draft', (
      tester,
    ) async {
      final sheet = await _pumpSheet(tester, _historySections());

      await _tapOption(tester, 'Type', 'Deposit');
      await _tapApply(tester);

      // Mutating what the caller received must not reach back into the sheet.
      sheet.result!.selections['Type']!.add('adjustment');
      expect(sheet.result!.select('Type'), {'deposit', 'adjustment'});

      await _tapApply(tester);
      expect(sheet.result!.select('Type'), {'deposit'});
    });
  });

  group('FilterSheet — Reset', () {
    testWidgets('clears every section at once', (tester) async {
      final sheet = await _pumpSheet(
        tester,
        _historySections(
          types: {'deposit', 'bill'},
          status: 'paid',
          category: 'food',
          preset: '30d',
        ),
      );

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await _tapApply(tester);

      final result = sheet.result!;
      expect(result.select('Type'), isEmpty);
      expect(result.single('Status'), isNull);
      expect(result.category, isNull);
      expect(result.preset, isNull);
      expect(result.range, isNull);
    });

    testWidgets('clears a custom range too', (tester) async {
      final sheet = await _pumpSheet(
        tester,
        _historySections(
          preset: FilterPeriods.custom,
          range: DateTimeRange(
            start: DateTime(2026, 3, 15),
            end: DateTime(2026, 4, 20),
          ),
        ),
      );

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await _tapApply(tester);

      expect(sheet.result!.range, isNull);
      expect(sheet.result!.preset, isNull);
    });

    testWidgets('Reset does not apply anything by itself', (tester) async {
      final sheet = await _pumpSheet(
        tester,
        _historySections(types: {'deposit'}),
      );

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(sheet.result, isNull);
    });
  });

  group('FilterSheetResult', () {
    test('an absent section reads as empty rather than throwing', () {
      const result = FilterSheetResult(
        selections: {},
        category: null,
        preset: null,
        range: null,
      );

      expect(result.select('Type'), isEmpty);
      expect(result.single('Status'), isNull);
    });

    test('a section the sheet never rendered is absent, not defaulted', () {
      const result = FilterSheetResult(
        selections: {
          'Type': {'bill'},
        },
        category: null,
        preset: null,
        range: null,
      );

      expect(result.select('Type'), {'bill'});
      // Bill History's member section is not part of History's sheet.
      expect(result.select('Member'), isEmpty);
    });
  });
}
