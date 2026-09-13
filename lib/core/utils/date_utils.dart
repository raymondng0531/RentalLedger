import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';

/// Date and time formatting utilities.
///
/// ## Locale is an argument, never global state
///
/// Every method here takes the locale it must format for. Nothing reads or
/// writes `Intl.defaultLocale`, and no `DateFormat` is constructed without an
/// explicit locale.
///
/// That is not stylistic. `DateFormat(pattern)` with no locale resolves through
/// `Intl.getCurrentLocale()`, which falls back to the *host platform's* locale.
/// Before this change the app's dates were therefore rendered in whatever
/// locale the device or browser happened to report — an English UI on a Malay
/// machine showed Malay month names, and no test could pin the behaviour
/// because it depended on the machine running it. Worse, `Intl.defaultLocale`
/// is process-global mutable state: setting it to follow the user's choice
/// would leak the setting into every other formatter in the process, and would
/// not by itself re-render anything already on screen.
///
/// Passing the locale instead makes formatting a function of what is actually
/// being displayed. When the user switches language, `MaterialApp` rebuilds
/// with a new [AppLocalizations], every call site re-reads it, and every date
/// on screen follows in the same frame — no restart, and no hidden state to get
/// out of sync.
///
/// ## Two parameter kinds
///
/// * Pattern formatters (`formatDate` and friends) take a plain locale **code**.
///   They produce numbers and month names only, so a code is all they need —
///   and a code is what text destined for *storage* can supply (see
///   [storageLocale]).
/// * Relative formatters (`formatRelative`, `formatActivityDate`) need whole
///   words — "Yesterday", "Just now" — so they take the [AppLocalizations]
///   itself, and read the locale code back off it for the date parts they
///   embed.
class DateFormatUtils {
  DateFormatUtils._();

  /// The locale used for text that is *written to storage* rather than drawn.
  ///
  /// Notification bodies are persisted in Firestore and are deliberately not
  /// localized, so they must not drift with the reader's language: the same
  /// event has to read the same way for every member of the house, and for the
  /// same member after they switch language. Pinning stored text to English
  /// keeps it stable and deterministic. Callers that write to storage pass this
  /// constant explicitly, so the choice is visible at the call site rather than
  /// hidden in a default.
  static const String storageLocale = 'en';

  /// Formats [date] to a full date string.
  /// Example: `Jan 15, 2026`
  static String formatDate(DateTime date, String localeCode) {
    return DateFormat('MMM d, yyyy', localeCode).format(date);
  }

  /// Formats [date] to a short date string.
  /// Example: `15 Jan 2026`
  static String formatDateShort(DateTime date, String localeCode) {
    return DateFormat('d MMM yyyy', localeCode).format(date);
  }

  /// Formats [date] to a full date + time string.
  /// Example: `5 Aug 2026, 8:12 PM`
  static String formatDateTime(DateTime date, String localeCode) {
    return DateFormat('d MMM yyyy, h:mm a', localeCode).format(date);
  }

  /// Formats [date] to just a time string.
  /// Example: `8:12 PM`
  static String formatTime(DateTime date, String localeCode) {
    return DateFormat('h:mm a', localeCode).format(date);
  }

  /// Formats [date] to a relative time string.
  /// Example: `2h ago`, `Yesterday`, `15 Jan`
  ///
  /// The thresholds are unchanged from the original: under a minute is "just
  /// now", under an hour counts minutes, under a day counts hours, exactly one
  /// day is "Yesterday", under a week counts days, under a year shows
  /// day-and-month, and beyond that shows the full date.
  ///
  /// [now] is injectable purely so tests can pin the reference instant and
  /// assert the boundaries; production callers omit it and get the real clock,
  /// which is what the original always did. This mirrors the existing
  /// `FilterPeriods.resolve({... DateTime? now})` convention.
  static String formatRelative(
    DateTime date,
    AppLocalizations l10n, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(date);

    if (diff.inMinutes < 1) return l10n.timeJustNow;
    if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
    if (diff.inDays == 1) return l10n.timeYesterday;
    if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
    if (diff.inDays < 365) {
      return DateFormat('d MMM', l10n.localeName).format(date);
    }
    return DateFormat('d MMM yyyy', l10n.localeName).format(date);
  }

  /// Formats [date] to a month-year string for grouping.
  /// Example: `January 2026`
  static String formatMonthYear(DateTime date, String localeCode) {
    return DateFormat('MMMM yyyy', localeCode).format(date);
  }

  /// Formats [date] to just the month name.
  /// Example: `January`
  static String formatMonthOnly(DateTime date, String localeCode) {
    return DateFormat('MMMM', localeCode).format(date);
  }

  /// Formats [date] for an activity timeline.
  /// Example: `Today · 10:35 PM`, `Yesterday · 10:35 PM`, `6 Aug 2026 · 10:35 PM`
  ///
  /// [now] is injectable for the same reason as on [formatRelative].
  static String formatActivityDate(
    DateTime date,
    AppLocalizations l10n, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final time = DateFormat('h:mm a', l10n.localeName).format(date);
    if (_isSameDay(date, reference)) return '${l10n.timeToday} · $time';

    final yesterday = reference.subtract(const Duration(days: 1));
    if (_isSameDay(date, yesterday)) return '${l10n.timeYesterday} · $time';

    final day = DateFormat('d MMM yyyy', l10n.localeName).format(date);
    return '$day · $time';
  }

  /// Returns `true` if [date] is within the current month.
  ///
  /// Locale-independent: which month it is does not depend on the language it
  /// is read in, so this takes no locale.
  static bool isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  /// Returns `true` if [date] is today.
  ///
  /// Locale-independent, like [isCurrentMonth]. [formatActivityDate], which
  /// does need a pinnable reference instant, compares days through the private
  /// helper instead of through this.
  static bool isToday(DateTime date) => _isSameDay(date, DateTime.now());

  /// Do [a] and [b] fall on the same calendar day?
  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
