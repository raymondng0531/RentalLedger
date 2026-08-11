import 'package:intl/intl.dart';

/// Date and time formatting utilities.
class DateFormatUtils {
  DateFormatUtils._();

  /// Formats [date] to a full date string.
  /// Example: `Jan 15, 2026`
  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  /// Formats [date] to a short date string.
  /// Example: `15 Jan 2026`
  static String formatDateShort(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  /// Formats [date] to a full date + time string.
  /// Example: `5 Aug 2026, 8:12 PM`
  static String formatDateTime(DateTime date) {
    return DateFormat('d MMM yyyy, h:mm a').format(date);
  }

  /// Formats [date] to just a time string.
  /// Example: `8:12 PM`
  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  /// Formats [date] to a relative time string.
  /// Example: `2h ago`, `Yesterday`, `15 Jan`
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return DateFormat('d MMM').format(date);
    return DateFormat('d MMM yyyy').format(date);
  }

  /// Formats [date] to a month-year string for grouping.
  /// Example: `January 2026`
  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  /// Formats [date] to just the month name.
  /// Example: `January`
  static String formatMonthOnly(DateTime date) {
    return DateFormat('MMMM').format(date);
  }

  /// Formats [date] for an activity timeline.
  /// Example: `Today · 10:35 PM`, `Yesterday · 10:35 PM`, `6 Aug 2026 · 10:35 PM`
  static String formatActivityDate(DateTime date) {
    final time = DateFormat('h:mm a').format(date);
    if (isToday(date)) return 'Today · $time';
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday · $time';
    }
    return '${DateFormat('d MMM yyyy').format(date)} · $time';
  }

  /// Returns `true` if [date] is within the current month.
  static bool isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  /// Returns `true` if [date] is today.
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}
