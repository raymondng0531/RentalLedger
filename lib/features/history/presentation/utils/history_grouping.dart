import '../../../../core/utils/date_utils.dart';
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

/// Groups an already-filtered, newest-first list of events into calendar
/// months, newest month first, events newest-first within each month.
///
/// Pure and free of Firebase so the ordering rules can be unit-tested.
List<MonthSection> groupEventsByMonth(List<HistoryEvent> events) {
  if (events.isEmpty) return const [];

  final sections = <MonthSection>[];
  MonthSection? current;

  for (final event in events) {
    final year = event.date.year;
    final month = event.date.month;

    // Same month as the previous event → append to the open section.
    if (current != null && current.year == year && current.month == month) {
      current.events.add(event);
      continue;
    }

    // New month → close the previous section and open a new one.
    current = MonthSection(
      label: monthYearHeader(event.date),
      year: year,
      month: month,
      events: [event],
    );
    sections.add(current);
  }

  return sections;
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
String monthYearHeader(DateTime date) {
  return DateFormatUtils.formatMonthYear(date).toUpperCase();
}
