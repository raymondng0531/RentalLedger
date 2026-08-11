import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/utils/date_utils.dart';

void main() {
  group('DateFormatUtils.formatDate', () {
    test('formats to MMM d, yyyy', () {
      expect(
        DateFormatUtils.formatDate(DateTime(2026, 7, 15)),
        'Jul 15, 2026',
      );
    });
  });

  group('DateFormatUtils.formatMonthYear', () {
    test('formats month and year', () {
      expect(
        DateFormatUtils.formatMonthYear(DateTime(2026, 1)),
        'January 2026',
      );
    });
  });

  group('DateFormatUtils.formatRelative', () {
    test('just now for under a minute', () {
      final date = DateTime.now().subtract(const Duration(seconds: 30));
      expect(DateFormatUtils.formatRelative(date), 'Just now');
    });

    test('minutes ago', () {
      final date = DateTime.now().subtract(const Duration(minutes: 5));
      expect(DateFormatUtils.formatRelative(date), '5m ago');
    });

    test('hours ago', () {
      final date = DateTime.now().subtract(const Duration(hours: 3));
      expect(DateFormatUtils.formatRelative(date), '3h ago');
    });

    test('yesterday', () {
      final date = DateTime.now().subtract(const Duration(days: 1));
      expect(DateFormatUtils.formatRelative(date), 'Yesterday');
    });

    test('days ago', () {
      final date = DateTime.now().subtract(const Duration(days: 3));
      expect(DateFormatUtils.formatRelative(date), '3d ago');
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
