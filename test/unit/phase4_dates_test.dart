import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:rental_ledger/core/utils/date_utils.dart';
import 'package:rental_ledger/features/expenses/domain/entities/bill_entity.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Phase 4 — date localization.
///
/// The formatters take their locale as an argument. These tests pin both
/// languages explicitly, so the results are the same on every machine — the
/// defect this phase removed was precisely that date output used to follow the
/// *host* locale and could not be asserted at all.

late AppLocalizations _en;
late AppLocalizations _ms;

/// Every test that needs a stable "now" pins one, so the relative thresholds
/// are asserted at their boundaries rather than wherever the clock happened to
/// be when the suite ran.
final DateTime _now = DateTime(2026, 8, 15, 12);

/// A bill due [daysFromToday] from today, using calendar arithmetic so the
/// result does not depend on the machine's timezone or DST rules.
BillEntity _billDueIn(int daysFromToday) {
  final today = DateTime.now();
  return BillEntity(
    billId: 'b1',
    houseId: 'h1',
    title: 'Electricity',
    dueDate: DateTime(today.year, today.month, today.day + daysFromToday),
    createdAt: today,
  );
}

void main() {
  setUpAll(() async {
    // `ms` is not compiled into intl, so its symbols must be loaded explicitly
    // outside a widget tree. (In the app, GlobalMaterialLocalizations does this.)
    await initializeDateFormatting();
    _en = await AppLocalizations.delegate.load(const Locale('en'));
    _ms = await AppLocalizations.delegate.load(const Locale('ms'));
  });

  group('English date formatting', () {
    test('full date', () {
      expect(DateFormatUtils.formatDate(DateTime(2026, 7, 15), 'en'),
          'Jul 15, 2026');
    });

    test('short date', () {
      expect(DateFormatUtils.formatDateShort(DateTime(2026, 8, 5), 'en'),
          '5 Aug 2026');
    });

    test('date and time', () {
      expect(
        DateFormatUtils.formatDateTime(DateTime(2026, 8, 5, 20, 12), 'en'),
        '5 Aug 2026, 8:12 PM',
      );
    });

    test('time only', () {
      expect(DateFormatUtils.formatTime(DateTime(2026, 8, 5, 20, 12), 'en'),
          '8:12 PM');
    });

    test('month and year', () {
      expect(DateFormatUtils.formatMonthYear(DateTime(2026, 1), 'en'),
          'January 2026');
    });

    test('month name only', () {
      expect(DateFormatUtils.formatMonthOnly(DateTime(2026, 7), 'en'), 'July');
    });
  });

  group('Malay date formatting', () {
    test('short date uses Malay month abbreviations', () {
      expect(DateFormatUtils.formatDate(DateTime(2026, 8, 15), 'ms'),
          'Ogo 15, 2026');
      expect(DateFormatUtils.formatDateShort(DateTime(2026, 8, 5), 'ms'),
          '5 Ogo 2026');
    });

    test('full month and year', () {
      expect(DateFormatUtils.formatMonthYear(DateTime(2026, 1), 'ms'),
          'Januari 2026');
      expect(DateFormatUtils.formatMonthOnly(DateTime(2026, 8), 'ms'), 'Ogos');
    });

    test('date and time uses the Malay meridiem marker', () {
      expect(
        DateFormatUtils.formatDateTime(DateTime(2026, 8, 5, 20, 12), 'ms'),
        '5 Ogo 2026, 8:12 PTG',
      );
      expect(DateFormatUtils.formatTime(DateTime(2026, 8, 5, 20, 12), 'ms'),
          '8:12 PTG');
    });
  });

  group('month names', () {
    test('all twelve English month names', () {
      const expected = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      for (var i = 1; i <= 12; i++) {
        expect(DateFormatUtils.formatMonthOnly(DateTime(2026, i), 'en'),
            expected[i - 1]);
      }
    });

    test('all twelve Malay month names', () {
      const expected = [
        'Januari', 'Februari', 'Mac', 'April', 'Mei', 'Jun',
        'Julai', 'Ogos', 'September', 'Oktober', 'November', 'Disember',
      ];
      for (var i = 1; i <= 12; i++) {
        expect(DateFormatUtils.formatMonthOnly(DateTime(2026, i), 'ms'),
            expected[i - 1]);
      }
    });
  });

  group('relative time (English)', () {
    test('under a minute is "Just now"', () {
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(seconds: 59)), _en, now: _now),
        'Just now',
      );
    });

    test('exactly one minute flips to minutes', () {
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(seconds: 60)), _en, now: _now),
        '1m ago',
      );
    });

    test('minutes', () {
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(minutes: 5)), _en, now: _now),
        '5m ago',
      );
    });

    test('exactly one hour flips to hours', () {
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(minutes: 60)), _en, now: _now),
        '1h ago',
      );
    });

    test('hours', () {
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(hours: 3)), _en, now: _now),
        '3h ago',
      );
    });

    test('just under a day is still hours', () {
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(hours: 23)), _en, now: _now),
        '23h ago',
      );
    });

    test('exactly one day is "Yesterday"', () {
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(hours: 25)), _en, now: _now),
        'Yesterday',
      );
    });

    test('days', () {
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(days: 3)), _en, now: _now),
        '3d ago',
      );
    });

    test('six days is still a day count', () {
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(days: 6)), _en, now: _now),
        '6d ago',
      );
    });

    test('a week or more falls back to a short date', () {
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(days: 10)), _en, now: _now),
        '5 Aug',
      );
    });

    test('over a year falls back to a full date', () {
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(days: 400)), _en, now: _now),
        '11 Jul 2025',
      );
    });
  });

  group('relative time (Malay)', () {
    test('the same instants read in Malay', () {
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(seconds: 30)), _ms, now: _now),
        'Baru sahaja',
      );
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(minutes: 5)), _ms, now: _now),
        '5 min lalu',
      );
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(hours: 3)), _ms, now: _now),
        '3 jam lalu',
      );
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(hours: 25)), _ms, now: _now),
        'Semalam',
      );
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(days: 3)), _ms, now: _now),
        '3 hari lalu',
      );
    });

    test('the date fallback is Malay too, not English', () {
      expect(
        DateFormatUtils.formatRelative(
            _now.subtract(const Duration(days: 10)), _ms, now: _now),
        '5 Ogo',
      );
    });
  });

  group('Today / Yesterday / Tomorrow', () {
    test('English', () {
      expect(_en.timeToday, 'Today');
      expect(_en.timeYesterday, 'Yesterday');
      expect(_en.timeTomorrow, 'Tomorrow');
    });

    test('Malay', () {
      expect(_ms.timeToday, 'Hari ini');
      expect(_ms.timeYesterday, 'Semalam');
      expect(_ms.timeTomorrow, 'Esok');
    });

    test('activity dates: today and yesterday are named, older is dated', () {
      final at = DateTime(2026, 8, 15, 10, 35);
      expect(DateFormatUtils.formatActivityDate(at, _en, now: _now),
          'Today · 10:35 AM');
      expect(
        DateFormatUtils.formatActivityDate(
            DateTime(2026, 8, 14, 10, 35), _en, now: _now),
        'Yesterday · 10:35 AM',
      );
      expect(
        DateFormatUtils.formatActivityDate(
            DateTime(2026, 8, 6, 10, 35), _en, now: _now),
        '6 Aug 2026 · 10:35 AM',
      );
    });

    test('activity dates in Malay', () {
      expect(
        DateFormatUtils.formatActivityDate(
            DateTime(2026, 8, 15, 10, 35), _ms, now: _now),
        'Hari ini · 10:35 PG',
      );
      expect(
        DateFormatUtils.formatActivityDate(
            DateTime(2026, 8, 14, 10, 35), _ms, now: _now),
        'Semalam · 10:35 PG',
      );
    });
  });

  group('bill countdown — days left', () {
    test('English singular and plural', () {
      expect(_en.billDaysLeft(1), '1 day left');
      expect(_en.billDaysLeft(5), '5 days left');
    });

    test('Malay has no plural form', () {
      expect(_ms.billDaysLeft(1), '1 hari lagi');
      expect(_ms.billDaysLeft(5), '5 hari lagi');
    });

    test('countdownLabel: due today, tomorrow, and further out', () {
      expect(_billDueIn(0).countdownLabel(_en), 'Due Today');
      expect(_billDueIn(1).countdownLabel(_en), 'Tomorrow');
      expect(_billDueIn(5).countdownLabel(_en), '5 days left');
    });

    test('countdownLabel in Malay', () {
      expect(_billDueIn(0).countdownLabel(_ms), 'Bayar Hari Ini');
      expect(_billDueIn(1).countdownLabel(_ms), 'Esok');
      expect(_billDueIn(5).countdownLabel(_ms), '5 hari lagi');
    });
  });

  group('bill countdown — overdue', () {
    test('English singular and plural', () {
      expect(_en.billOverdueByDays(1), 'Overdue by 1 day');
      expect(_en.billOverdueByDays(3), 'Overdue by 3 days');
    });

    test('Malay singular and plural read the same', () {
      expect(_ms.billOverdueByDays(1), 'Lewat 1 hari');
      expect(_ms.billOverdueByDays(3), 'Lewat 3 hari');
    });

    test('countdownLabel reports overdue days by magnitude', () {
      expect(_billDueIn(-1).countdownLabel(_en), 'Overdue by 1 day');
      expect(_billDueIn(-3).countdownLabel(_en), 'Overdue by 3 days');
      expect(_billDueIn(-3).countdownLabel(_ms), 'Lewat 3 hari');
    });

    test('the urgency and day maths stay locale-independent', () {
      // Only the text is localized — nothing that branches on a bill's state
      // may depend on which language it is being read in.
      expect(_billDueIn(-1).isOverdue, isTrue);
      expect(_billDueIn(0).isDueToday, isTrue);
      expect(_billDueIn(-3).daysLeft, -3);
      expect(_billDueIn(-3).urgency, BillUrgency.red);
      expect(_billDueIn(5).urgency, BillUrgency.orange);
      expect(_billDueIn(20).urgency, BillUrgency.green);
    });
  });

  group('no hidden global locale state', () {
    test('Intl.defaultLocale is never set', () {
      expect(Intl.defaultLocale, isNull);
      DateFormatUtils.formatDate(DateTime(2026, 7, 15), 'ms');
      DateFormatUtils.formatRelative(_now, _ms, now: _now);
      expect(
        Intl.defaultLocale,
        isNull,
        reason: 'formatting must not mutate process-global intl state',
      );
    });

    test('formatting for one locale does not leak into the next call', () {
      expect(DateFormatUtils.formatDate(DateTime(2026, 8, 15), 'ms'),
          'Ogo 15, 2026');
      expect(DateFormatUtils.formatDate(DateTime(2026, 8, 15), 'en'),
          'Aug 15, 2026');
      expect(DateFormatUtils.formatDate(DateTime(2026, 8, 15), 'ms'),
          'Ogo 15, 2026');
    });

    testWidgets('switching locale re-renders dates without a restart',
        (tester) async {
      final locale = ValueNotifier<Locale>(const Locale('en'));
      addTearDown(locale.dispose);

      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, value, _) => MaterialApp(
            locale: value,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Column(
                  children: [
                    Text(DateFormatUtils.formatDate(
                        DateTime(2026, 8, 15), l10n.localeName)),
                    Text(DateFormatUtils.formatRelative(
                        DateTime(2026, 8, 12, 12), l10n,
                        now: DateTime(2026, 8, 15, 12))),
                    Text(DateFormatUtils.formatActivityDate(
                        DateTime(2026, 8, 15, 10, 35), l10n,
                        now: DateTime(2026, 8, 15, 12))),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Aug 15, 2026'), findsOneWidget);
      expect(find.text('3d ago'), findsOneWidget);
      expect(find.text('Today · 10:35 AM'), findsOneWidget);

      locale.value = const Locale('ms');
      await tester.pumpAndSettle();

      expect(find.text('Ogo 15, 2026'), findsOneWidget);
      expect(find.text('3 hari lalu'), findsOneWidget);
      expect(find.text('Hari ini · 10:35 PG'), findsOneWidget);

      locale.value = const Locale('en');
      await tester.pumpAndSettle();

      expect(find.text('Aug 15, 2026'), findsOneWidget);
      expect(find.text('3d ago'), findsOneWidget);
      expect(find.text('Ogo 15, 2026'), findsNothing);
    });
  });
}
