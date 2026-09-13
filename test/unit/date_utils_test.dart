import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:rental_ledger/core/utils/date_utils.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// The formatters take their locale as an argument — never from
/// `Intl.defaultLocale` — so every case here names the locale it expects.
late AppLocalizations _en;

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    _en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('DateFormatUtils.formatDate', () {
    test('formats to MMM d, yyyy', () {
      expect(
        DateFormatUtils.formatDate(DateTime(2026, 7, 15), 'en'),
        'Jul 15, 2026',
      );
    });
  });

  group('DateFormatUtils.formatMonthYear', () {
    test('formats month and year', () {
      expect(
        DateFormatUtils.formatMonthYear(DateTime(2026, 1), 'en'),
        'January 2026',
      );
    });
  });

  group('DateFormatUtils.formatRelative', () {
    test('just now for under a minute', () {
      final date = DateTime.now().subtract(const Duration(seconds: 30));
      expect(DateFormatUtils.formatRelative(date, _en), 'Just now');
    });

    test('minutes ago', () {
      final date = DateTime.now().subtract(const Duration(minutes: 5));
      expect(DateFormatUtils.formatRelative(date, _en), '5m ago');
    });

    test('hours ago', () {
      final date = DateTime.now().subtract(const Duration(hours: 3));
      expect(DateFormatUtils.formatRelative(date, _en), '3h ago');
    });

    test('yesterday', () {
      final date = DateTime.now().subtract(const Duration(days: 1));
      expect(DateFormatUtils.formatRelative(date, _en), 'Yesterday');
    });

    test('days ago', () {
      final date = DateTime.now().subtract(const Duration(days: 3));
      expect(DateFormatUtils.formatRelative(date, _en), '3d ago');
    });

    test('older than a week falls back to a short date', () {
      final date = DateTime.now().subtract(const Duration(days: 30));
      expect(
        DateFormatUtils.formatRelative(date, _en),
        DateFormat('d MMM', 'en').format(date),
      );
    });
  });

  group('DateFormatUtils.isCurrentMonth', () {
    test('true for current month', () {
      expect(DateFormatUtils.isCurrentMonth(DateTime.now()), isTrue);
    });

    test('false for other month', () {
      final other = DateTime.now().subtract(const Duration(days: 60));
      expect(DateFormatUtils.isCurrentMonth(other), isFalse);
    });
  });

  group('DateFormatUtils.isToday', () {
    test('true for today', () {
      expect(DateFormatUtils.isToday(DateTime.now()), isTrue);
    });

    test('false for yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(DateFormatUtils.isToday(yesterday), isFalse);
    });
  });
}
