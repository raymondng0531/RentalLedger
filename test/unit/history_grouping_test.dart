import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rental_ledger/features/history/presentation/providers/history_provider.dart';
import 'package:rental_ledger/features/history/presentation/utils/history_grouping.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// The month header is localized, so the grouping functions take a locale.
///
/// Every case here runs in English — the wording this suite asserted before the
/// migration. The Malay header is covered in `phase4_dates_test.dart`.
late AppLocalizations _en;

HistoryEvent _event(String id, DateTime date, {String? title}) => HistoryEvent(
      id: id,
      type: HistoryEventType.deposit,
      title: title,
      amount: 100,
      date: date,
    );

void main() {
  setUpAll(() async {
    // The `ms` date symbols are not compiled into intl, so they have to be
    // loaded explicitly. Harmless for English, and it keeps this suite honest
    // if a future case adds a Malay header.
    await initializeDateFormatting();
    _en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('groupEventsByMonth', () {
    test('groups a newest-first feed into calendar months, newest month first',
        () {
      final sections = groupEventsByMonth([
        _event('a', DateTime(2026, 8, 15)),
        _event('b', DateTime(2026, 8, 5)),
        _event('c', DateTime(2026, 7, 20)),
        _event('d', DateTime(2026, 7)),
        _event('e', DateTime(2026, 6, 10)),
      ], _en);

      expect(sections.map((s) => s.label), ['AUGUST 2026', 'JULY 2026', 'JUNE 2026']);
      expect(sections.map((s) => s.year), [2026, 2026, 2026]);
      expect(sections.map((s) => s.month), [8, 7, 6]);
    });

    test('preserves newest-first ordering of events within each month', () {
      final sections = groupEventsByMonth([
        _event('a', DateTime(2026, 8, 20)),
        _event('b', DateTime(2026, 8, 10)),
        _event('c', DateTime(2026, 8)),
      ], _en);

      expect(sections, hasLength(1));
      expect(sections.single.events.map((e) => e.id), ['a', 'b', 'c']);
    });

    test('a year boundary produces separate, correctly ordered sections', () {
      final sections = groupEventsByMonth([
        _event('jan', DateTime(2026, 1, 15)),
        _event('dec', DateTime(2025, 12, 20)),
      ], _en);

      expect(sections, hasLength(2));
      expect(sections[0].label, 'JANUARY 2026');
      expect(sections[1].label, 'DECEMBER 2025');
    });

    test('returns no sections for an empty feed (no empty month headers)', () {
      expect(groupEventsByMonth([], _en), isEmpty);
    });

    test('repeated months merge into a single section (no duplicate headers)',
        () {
      final sections = groupEventsByMonth([
        _event('a', DateTime(2026, 8, 10)),
        _event('b', DateTime(2026, 8)),
        _event('c', DateTime(2026, 8, 12)),
      ], _en);

      expect(sections, hasLength(1));
      expect(sections.single.events, hasLength(3));
    });
  });

  group('buildHistoryRows', () {
    test('interleaves a month header before each month\'s events', () {
      final sections = groupEventsByMonth([
        _event('a', DateTime(2026, 8, 15)),
        _event('b', DateTime(2026, 7, 20)),
        _event('c', DateTime(2026, 7)),
      ], _en);
      final rows = buildHistoryRows(sections);

      expect(rows, hasLength(5)); // 2 headers + 3 events
      expect(rows[0], isA<MonthHeaderRow>());
      expect((rows[0] as MonthHeaderRow).section.label, 'AUGUST 2026');
      expect(rows[1], isA<HistoryEventRow>());
      expect(rows[2], isA<MonthHeaderRow>());
      expect((rows[2] as MonthHeaderRow).section.label, 'JULY 2026');
      expect(rows[3], isA<HistoryEventRow>());
      expect(rows[4], isA<HistoryEventRow>());
    });

    test('every row has a stable, unique key for animated-list diffing', () {
      final rows = buildHistoryRows(groupEventsByMonth([
        _event('e1', DateTime(2026, 8, 15)),
        _event('e2', DateTime(2026, 7, 20)),
        _event('e3', DateTime(2026, 7)),
      ], _en));

      final keys = rows.map((r) => r.key).toSet();
      expect(keys.length, rows.length, reason: 'every row key must be unique');
      expect((rows[0] as MonthHeaderRow).key, 'month-2026-8');
      expect((rows[1] as HistoryEventRow).key, 'e1');
    });

    test('no rows for no sections', () {
      expect(buildHistoryRows([]), isEmpty);
    });
  });

  group('search + grouping (filter runs BEFORE grouping)', () {
    test('filtered feed yields sections only for months that still match', () {
      // Full feed: August, July and June events.
      final feed = [
        _event('a1', DateTime(2026, 8, 15), title: 'Groceries'),
        _event('a2', DateTime(2026, 8, 5), title: 'Rent'),
        _event('j1', DateTime(2026, 7, 20), title: 'Groceries'),
        _event('j2', DateTime(2026, 7), title: 'Internet'),
        _event('jn1', DateTime(2026, 6, 10), title: 'Rent'),
      ];

      // Simulate the History page's search: filter first, group second.
      const query = 'groceries';
      final filtered = feed
          .where((e) => (e.title ?? '').toLowerCase().contains(query))
          .toList();
      final sections = groupEventsByMonth(filtered, _en);

      // Only August and July still have matches — no empty June header.
      expect(sections.map((s) => s.label), ['AUGUST 2026', 'JULY 2026']);
      expect(sections.first.events.single.id, 'a1');
      expect(sections.last.events.single.id, 'j1');
    });

    test('a search with no matches produces zero sections', () {
      final sections = groupEventsByMonth(
        [_event('a1', DateTime(2026, 8, 15), title: 'Rent')]
            .where((e) => (e.title ?? '').contains('zzz'))
            .toList(),
        _en,
      );
      expect(sections, isEmpty);
    });
  });

  group('monthYearHeader', () {
    test('formats and uppercases the month + year', () {
      expect(monthYearHeader(DateTime(2026, 8, 3), _en), 'AUGUST 2026');
      expect(monthYearHeader(DateTime(2025, 12, 31), _en), 'DECEMBER 2025');
    });
  });
}
