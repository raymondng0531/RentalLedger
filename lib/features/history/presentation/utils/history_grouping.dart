import '../../../../core/utils/date_utils.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/history_provider.dart';

/// A calendar-month section of history events, used to render e-wallet style
/// month headers ("AUGUST 2026") above each month's events.
///
/// Sections are produced **after** filtering/search, so a month never appears
/// unless it has at least one matching event — no empty month headers.
class MonthSection {
  const MonthSection({
    required this.label,
    required this.year,
    required this.month,
    required this.events,
  });

  /// Uppercase month header, e.g. "AUGUST 2026".
  final String label;

  final int year;
  final int month;

  /// Events in this month, newest-first (the order they arrived in).
  final List<HistoryEvent> events;
}

/// One row in the sectioned History list — either a month header or an event.
///
/// A plain sealed type so [ImplicitAnimatedList] can diff by stable key while
/// the item builder switches on the row kind.
sealed class HistoryRow {
  const HistoryRow();

  /// Stable, unique key for the animated list diffing.
  String get key;
}

/// A month header row ("AUGUST 2026").
class MonthHeaderRow extends HistoryRow {
  const MonthHeaderRow(this.section);

  final MonthSection section;

  @override
  String get key => 'month-${section.year}-${section.month}';
}

/// An event row (the existing activity tile).
class HistoryEventRow extends HistoryRow {
  const HistoryEventRow(this.event);

  final HistoryEvent event;

  @override
  String get key => event.id;
}

/// A calendar-month section over ANY dated rows — the generic form of
/// [MonthSection].
///
/// Bill History groups `BillHistoryEntry` rather than `HistoryEvent`, and the
/// month-opening/closing rule is the part that must not be reimplemented: two
/// copies would be free to disagree about where a month ends. [groupEventsByMonth]
/// delegates here, so there is exactly ONE implementation of the rule.
class DatedMonthSection<T> {
  const DatedMonthSection({
    required this.label,
    required this.year,
    required this.month,
    required this.items,
  });

  final String label;
  final int year;
  final int month;

  /// Items in this month, in the order they arrived (newest-first).
  final List<T> items;
}

/// Groups an already-filtered, newest-first list into calendar months, newest
/// month first, items newest-first within each month.
///
/// [dateOf] is the date each row is filed under. For History that is the
/// event's own date; for Bill History it is the row's filing date (payment
/// date when paid, due date otherwise).
///
/// Pure and free of Firebase so the ordering rules can be unit-tested.
///
/// [l10n] supplies the locale for the month header. It is passed in rather than
/// read from anywhere global so the header re-renders with the rest of the
/// screen when the user changes language.
List<DatedMonthSection<T>> groupItemsByMonth<T>(
  List<T> items,
  DateTime Function(T) dateOf,
  AppLocalizations l10n,
) {
  if (items.isEmpty) return const [];

  final sections = <DatedMonthSection<T>>[];
  DatedMonthSection<T>? current;

  for (final item in items) {
    final date = dateOf(item);
    final year = date.year;
    final month = date.month;

    // Same month as the previous item → append to the open section.
    if (current != null && current.year == year && current.month == month) {
      current.items.add(item);
      continue;
    }

    // New month → close the previous section and open a new one.
    current = DatedMonthSection<T>(
      label: monthYearHeader(date, l10n),
      year: year,
      month: month,
      items: [item],
    );
    sections.add(current);
  }

  return sections;
}

/// Groups an already-filtered, newest-first list of events into calendar
/// months, newest month first, events newest-first within each month.
///
/// Behaviour is unchanged — this now delegates to [groupItemsByMonth] so the
/// month rule has a single implementation.
List<MonthSection> groupEventsByMonth(
  List<HistoryEvent> events,
  AppLocalizations l10n,
) {
  return groupItemsByMonth(events, (e) => e.date, l10n)
      .map(
        (section) => MonthSection(
          label: section.label,
          year: section.year,
          month: section.month,
          events: section.items,
        ),
      )
      .toList();
}

/// Flattens month sections into the flat row list the animated list renders:
/// one header row per month, followed by that month's event rows.
///
/// Month headers animate in/out alongside the events as filtering changes.
List<HistoryRow> buildHistoryRows(List<MonthSection> sections) {
  final rows = <HistoryRow>[];
  for (final section in sections) {
    rows.add(MonthHeaderRow(section));
    rows.addAll(section.events.map(HistoryEventRow.new));
  }
  return rows;
}

/// Formats a date as an uppercase month + year header ("AUGUST 2026").
///
/// Uppercasing after formatting is safe for both shipped locales — `toUpperCase`
/// is a no-op on Malay month names (`OGOS 2026`), and on any locale where it is
/// not, the header is a section label rather than a word inside a sentence.
String monthYearHeader(DateTime date, AppLocalizations l10n) {
  return DateFormatUtils.formatMonthYear(date, l10n.localeName).toUpperCase();
}
