import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// The app's shared date-period vocabulary, and the one place that turns a
/// period choice into an actual date range.
///
/// This lived inside `HistoryPage._activeRange` and was private to it. It is
/// lifted out unchanged so Bill History filters by exactly the same periods,
/// with exactly the same boundaries — two screens cannot drift into two
/// different meanings of "Last 7 Days".
///
/// ## The convention (unchanged, and deliberately so)
///
/// Ranges are HALF-OPEN: `start <= date < end`. That is what makes the presets
/// expressible at all — "Today" is `[today 00:00, tomorrow 00:00)`, so an event
/// at 23:59 tonight is inside it and one at 00:00 tomorrow is not. Callers
/// therefore test `!date.isBefore(start) && date.isBefore(end)`.
///
/// The custom range is the one place this is not true, and it is a
/// long-standing quirk rather than an oversight: the date picker hands back the
/// end date at midnight, and the range is used as given. A custom range ending
/// on the 15th therefore admits the 15th only up to 00:00. This is preserved
/// exactly, because changing it would silently change what History shows for
/// every custom range a user has already applied. See the note on [resolve].
class FilterPeriods {
  const FilterPeriods._();

  /// The preset keys, in display order.
  ///
  /// These are **stable internal keys**: they are what a screen stores for the
  /// user's choice and what the switch in [resolve] matches on. They are not
  /// display text and must never be translated — the label for a key comes from
  /// [labelFor].
  static const List<String> presets = [
    'today',
    'yesterday',
    '7d',
    '30d',
    '90d',
    'month',
    'lastmonth',
  ];

  /// The key the sheet stores when the user picks an explicit date range.
  /// Not a member of [presets] — it is a marker, and the range itself carries
  /// the meaning.
  static const String custom = 'custom';

  /// Resolves a period choice to a half-open `[start, end)` range, or `null`
  /// for "All" (no date filtering).
  ///
  /// [now] is injectable purely so tests can pin "today" and assert the
  /// boundaries; production callers omit it and get the real clock, which is
  /// what the original inline getter always did.
  ///
  /// A [preset] of [custom] — or anything unrecognised, including `null` —
  /// falls through to [range]. With no range that means `null`, i.e. no
  /// filtering, which is the original `default:` branch.
  ///
  /// NOTE on the custom branch: the end is used verbatim, not extended to the
  /// end of that day. Preserved from the original implementation — see the
  /// class comment.
  static (DateTime, DateTime)? resolve({
    String? preset,
    DateTimeRange? range,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);

    switch (preset) {
      case 'today':
        return (today, today.add(const Duration(days: 1)));
      case 'yesterday':
        return (today.subtract(const Duration(days: 1)), today);
      case '7d':
        return (
          today.subtract(const Duration(days: 6)),
          today.add(const Duration(days: 1)),
        );
      case '30d':
        return (
          today.subtract(const Duration(days: 29)),
          today.add(const Duration(days: 1)),
        );
      case '90d':
        return (
          today.subtract(const Duration(days: 89)),
          today.add(const Duration(days: 1)),
        );
      case 'month':
        return (
          DateTime(current.year, current.month, 1),
          DateTime(current.year, current.month + 1, 1),
        );
      case 'lastmonth':
        return (
          DateTime(current.year, current.month - 1, 1),
          DateTime(current.year, current.month, 1),
        );
      default:
        return range != null ? (range.start, range.end) : null;
    }
  }

  /// Is [date] inside the half-open range `[start, end)`?
  ///
  /// The single shared implementation of the boundary test, so History and
  /// Bill History cannot disagree about whether a date on the edge is in.
  static bool contains((DateTime, DateTime) range, DateTime date) {
    final (start, end) = range;
    return !date.isBefore(start) && date.isBefore(end);
  }

  /// The human label for a period choice, as shown on the active-filter chips
  /// and on the option tiles in the filter sheet.
  ///
  /// Takes the locale explicitly rather than reading it from anywhere global, so
  /// the label follows a language change in the same frame as everything else.
  /// The [preset] keys themselves are untouched — only the text shown for them
  /// changes.
  static String labelFor(String? preset, AppLocalizations l10n) {
    return switch (preset) {
      null => l10n.periodAll,
      custom => l10n.periodCustomRange,
      'today' => l10n.timeToday,
      'yesterday' => l10n.timeYesterday,
      '7d' => l10n.periodLast7Days,
      '30d' => l10n.periodLast30Days,
      '90d' => l10n.periodLast90Days,
      'month' => l10n.periodThisMonth,
      'lastmonth' => l10n.periodLastMonth,
      // Anything unrecognised means no filtering, which is what the original
      // `indexOf`-then-`-1` fallback did.
      _ => l10n.periodAll,
    };
  }
}
