import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rental_ledger/core/utils/currency_utils.dart';
import 'package:rental_ledger/features/reports/presentation/providers/reports_provider.dart';
import 'package:rental_ledger/features/reports/presentation/services/report_pdf_generator.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// The visible text of a generated PDF, as one whitespace-collapsed string.
///
/// The `pdf` package compresses its content streams on the VM (`zlib.encode`),
/// so each stream is inflated first and the text-showing operators are then
/// unescaped and joined. Inflating with the same codec the generator wrote with
/// keeps this honest — nothing here re-implements the layout, it only reads
/// what the document actually says.
///
/// Text is emitted word by word (`(Money) Tj (In) Tj`), so the fragments are
/// rejoined with a space and runs of whitespace collapsed. That makes
/// `contains('Money In')` meaningful while still catching a dropped glyph,
/// which is what the encoding tests below rely on.
String _pdfText(Uint8List bytes) {
  final latin = String.fromCharCodes(bytes);
  final fragments = <String>[];

  // `stream` also occurs inside `endstream`; skipping those keeps the scan
  // from treating a terminator as a new stream.
  for (final open in RegExp(r'stream\r?\n').allMatches(latin)) {
    if (open.start > 0 && latin[open.start - 1] == 'd') continue;
    final close = latin.indexOf('endstream', open.end);
    if (close < 0) continue;

    List<int> inflated;
    try {
      inflated = zlib.decode(bytes.sublist(open.end, close));
    } on FormatException {
      // Not a Flate stream (an uncompressed or image stream) — not text.
      continue;
    }

    final content = String.fromCharCodes(inflated);
    final ops = RegExp(
      r'\((?:\\.|[^()\\])*\)\s*Tj|\[(?:[^\[\]\\]|\\.)*\]\s*TJ',
    );
    for (final op in ops.allMatches(content)) {
      final strings = RegExp(r'\((?:\\.|[^()\\])*\)')
          .allMatches(op.group(0)!)
          .map((s) => _unescape(s.group(0)!.substring(1, s.group(0)!.length - 1)));
      fragments.add(strings.join());
    }
  }

  return fragments.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Undoes the escapes the PDF writer applies to a literal string.
String _unescape(String value) {
  final out = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    if (value[i] != r'\') {
      out.write(value[i]);
      continue;
    }
    i++;
    switch (value[i]) {
      case 'n':
        out.write('\n');
      case 'r':
        out.write('\r');
      case 't':
        out.write('\t');
      case 'b':
        out.write('\b');
      case 'f':
        out.write('\f');
      case '(':
        out.write('(');
      case ')':
        out.write(')');
      case r'\':
        out.write(r'\');
      default:
        // An octal escape: up to three digits.
        var digits = value[i];
        while (digits.length < 3 &&
            i + 1 < value.length &&
            RegExp(r'[0-7]').hasMatch(value[i + 1])) {
          digits += value[++i];
        }
        out.writeCharCode(int.parse(digits, radix: 8));
    }
  }
  return out.toString();
}

/// A report with activity in every section, so each one has something to say.
const ReportsData _sample = ReportsData(
  totalExpenses: 1250.50,
  totalDeposits: 3000,
  moneyIn: 3000,
  moneyOut: 1400,
  balance: 1600,
  allTimeBalance: 1600,
  highestCategoryName: 'Food',
  highestCategoryAmount: 700,
  largestExpense: 800,
  averageMonthlyExpense: 625.25,
  avgExpenseClaim: 416.83,
  pendingReimbursements: 250,
  avgDeposit: 1500,
  largestDeposit: 2000,
  billsPaid: 3,
  billsPending: 1,
  moneyOutBreakdown: MoneyOutBreakdown(
    expenseReimbursements: 900,
    directPayments: 300,
    billPayments: 200,
  ),
  categoryBreakdown: [
    CategorySpending(name: 'Food', amount: 700, color: 0xFF16A34A),
    CategorySpending(name: 'Rent', amount: 500, color: 0xFF2563EB),
    CategorySpending(name: 'Utilities', amount: 50.50, color: 0xFFF97316),
  ],
  monthlyTrend: [
    MonthlyComparison(month: 'Aug', moneyIn: 1800, moneyOut: 900),
    MonthlyComparison(month: 'Sep', moneyIn: 1200, moneyOut: 500),
  ],
);

/// A house that has recorded nothing — the page's empty state.
const ReportsData _empty = ReportsData();

/// A fixed stamp so the "generated on" line is assertable.
final DateTime _generatedAt = DateTime(2026, 9, 14, 14, 30);

late AppLocalizations _en;
late AppLocalizations _ms;

Future<Uint8List> _build(
  ReportsData data, {
  AppLocalizations? l10n,
  String period = 'All time',
  bool windowed = false,
}) {
  return ReportPdfGenerator.build(
    data: data,
    l10n: l10n ?? _en,
    periodLabel: period,
    windowed: windowed,
    generatedAt: _generatedAt,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    _en = await AppLocalizations.delegate.load(const Locale('en'));
    _ms = await AppLocalizations.delegate.load(const Locale('ms'));
  });

  group('ReportPdfGenerator.build', () {
    test('produces a real PDF', () async {
      final bytes = await _build(_sample);

      expect(bytes.length, greaterThan(1000));
      expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
      // The trailer every reader needs to find the cross-reference table.
      expect(String.fromCharCodes(bytes.sublist(bytes.length - 6)),
          contains('%%EOF'));
    });

    test('carries the title, period and generated stamp', () async {
      final text = _pdfText(await _build(_sample, period: 'This month'));

      // The product name is a proper noun and is never translated.
      expect(text, contains('Rental Ledger'));
      expect(text, contains('Financial Report'));
      expect(text, contains('Period'));
      expect(text, contains('This month'));
      expect(text, contains('Generated 14 Sep 2026, 2:30 PM'));
    });

    test('carries the summary figures, money formatted by CurrencyUtils',
        () async {
      final text = _pdfText(await _build(_sample));

      expect(text, contains('Summary'));
      expect(text, contains('Money In'));
      expect(text, contains('Money Out'));
      expect(text, contains('Current Balance'));
      expect(text, contains('Total Expenses'));
      expect(text, contains('Total Deposits'));
      expect(text, contains('Net Flow'));

      // Every amount goes through the app's own formatter, so the PDF agrees
      // with the screen — same symbol, same grouping, same two decimals.
      expect(text, contains(CurrencyUtils.format(3000, localeCode: 'en')));
      expect(text, contains(CurrencyUtils.format(1250.50, localeCode: 'en')));
      expect(text, contains(CurrencyUtils.format(1600, localeCode: 'en')));
      // Net Flow is deposits minus paid expenses — 3000 − 1250.50.
      expect(text, contains(CurrencyUtils.format(1749.50, localeCode: 'en')));
      expect(text, contains('RM 1,250.50'));
    });

    test('carries the insights', () async {
      final text = _pdfText(await _build(_sample));

      expect(text, contains('Insights'));
      expect(text, contains('Highest Expense Category'));
      // The seeded category name is localized, the amount is formatted.
      expect(text, contains('Food · RM 700.00'));
      expect(text, contains('Largest Expense Claim'));
      expect(text, contains('Expense Reimbursements'));
      expect(text, contains('Pending Reimbursements'));
      expect(text, contains('Average Monthly Expense'));
      expect(text, contains('Average Deposit'));
      expect(text, contains('Largest Deposit'));
      expect(text, contains('Bills Paid'));
      expect(text, contains('Bills Pending'));
      expect(text, contains(CurrencyUtils.format(250, localeCode: 'en')));
      // Counts are plain integers, not money.
      expect(text, contains('Bills Paid 3'));
      expect(text, contains('Bills Pending 1'));
    });

    test('renders the money-out buckets and their shares', () async {
      final text = _pdfText(await _build(_sample));

      expect(text, contains('Where the Money Goes'));
      expect(text, contains('Expense reimbursements'));
      expect(text, contains('Direct payments'));
      expect(text, contains('Bill payments'));
      // The empty Adjustment bucket is skipped, exactly as on the page.
      expect(text, isNot(contains('Adjustments')));
      // 900 of 1400 ≈ 64%, 300 ≈ 21%, 200 ≈ 14%.
      expect(text, contains('64%'));
      expect(text, contains('21%'));
      expect(text, contains('14%'));
      expect(text, contains('Total'));
      expect(text, contains('100%'));
    });

    test('renders the category breakdown as a table, highest first', () async {
      final text = _pdfText(await _build(_sample));

      expect(text, contains('Category Breakdown'));
      expect(text, contains('Share'));
      expect(text, contains('Food'));
      expect(text, contains('Rent'));
      expect(text, contains('Utilities'));
      // The breakdown total is the sum of the slices, not the expenses total.
      expect(text, contains(CurrencyUtils.format(1250.50, localeCode: 'en')));

      // Anchored to the table's own header row rather than the heading: this
      // sample spills onto a second page, and the running header printed above
      // the table contains "Rental Ledger" — so "Rent" would otherwise be found
      // in the running header and decide the comparison.
      final section = text.indexOf('Category Breakdown');
      expect(section, isNonNegative);
      final table = text.indexOf('Category Amount Share', section);
      expect(table, greaterThan(section));
      expect(text.indexOf('Food', table),
          lessThan(text.indexOf('Rent', table)),
          reason: 'the breakdown keeps the provider order (highest first)');
    });

    test('renders the monthly trend with a reconciling total', () async {
      final text = _pdfText(await _build(_sample));

      expect(text, contains('Monthly Trend'));
      expect(text, contains('Month'));
      expect(text, contains('Aug'));
      expect(text, contains('Sep'));
      // The trend's own total row: 3000 in, 1400 out, 1600 net.
      expect(text, contains(CurrencyUtils.format(1600, localeCode: 'en')));
    });

    test('an empty report renders a notice instead of a wall of zeros',
        () async {
      final text = _pdfText(await _build(_empty));

      expect(text, contains('No report data for this period.'));
      expect(text, contains('Rental Ledger'));
      // No sections pretending there is data.
      expect(text, isNot(contains('Summary')));
      expect(text, isNot(contains('Category Breakdown')));
      expect(text, isNot(contains('Monthly Trend')));
    });

    test('a period filter shows Net and calls out the all-time balance',
        () async {
      final text = _pdfText(await _build(_sample, windowed: true));

      expect(text, contains('Net'));
      expect(text, isNot(contains('Current Balance')));
      // The period's Net is not the account's balance, so the real figure is
      // still printed — the same call-out the page shows.
      expect(text, contains('Central Account balance (all time)'));
    });
  });

  group('localization', () {
    test('English labels', () async {
      final text = _pdfText(await _build(_sample, l10n: _en));

      expect(text, contains('Financial Report'));
      expect(text, contains('Summary'));
      expect(text, contains('Total Expenses'));
      expect(text, contains('Total Deposits'));
      expect(text, contains('Net Flow'));
      expect(text, contains('Month'));
      expect(text, contains('Share'));
      expect(text, contains('Total'));
      expect(text, contains('Category Breakdown'));
      expect(text, contains('Monthly Trend'));
      expect(text, contains('Where the Money Goes'));
    });

    test('Bahasa Melayu labels', () async {
      final text = _pdfText(
        await _build(_sample, l10n: _ms, period: 'Sepanjang masa'),
      );

      expect(text, contains('Rental Ledger'), reason: 'never translated');
      expect(text, contains('Laporan Kewangan'));
      expect(text, contains('Ringkasan'));
      expect(text, contains('Jumlah Perbelanjaan'));
      expect(text, contains('Jumlah Deposit'));
      expect(text, contains('Aliran Bersih'));
      expect(text, contains('Tempoh'));
      expect(text, contains('Sepanjang masa'));
      expect(text, contains('Bulan'));
      expect(text, contains('Peratus'));
      expect(text, contains('Jumlah Keseluruhan'));
      expect(text, contains('Pecahan Kategori'));
      expect(text, contains('Trend Bulanan'));
      expect(text, contains('Ke Mana Wang Pergi'));
      expect(text, contains('Wang Masuk'));
      expect(text, contains('Wang Keluar'));
      expect(text, contains('Baki Semasa'));

      // English must not leak through.
      expect(text, isNot(contains('Financial Report')));
      expect(text, isNot(contains('Summary')));
      expect(text, isNot(contains('Current Balance')));
    });

    test('the seeded category name follows the language', () async {
      expect(_pdfText(await _build(_sample, l10n: _en)), contains('Food'));
      expect(_pdfText(await _build(_sample, l10n: _ms)), contains('Makanan'));
    });

    test('the empty notice is localized', () async {
      final text = _pdfText(await _build(_empty, l10n: _ms));
      expect(text, contains('Tiada data laporan untuk tempoh ini.'));
    });

    test('money follows the locale number format', () async {
      final text = _pdfText(await _build(_sample, l10n: _ms));
      expect(text, contains(CurrencyUtils.format(1250.50, localeCode: 'ms')));
      expect(text, contains('RM 1,250.50'));
    });
  });

  group('stored data is never rewritten', () {
    test('a renamed category prints the household\'s own words', () async {
      const renamed = ReportsData(
        moneyIn: 100,
        moneyOut: 100,
        categoryBreakdown: [
          CategorySpending(name: 'Tandas Blok B', amount: 100),
        ],
      );

      final text = _pdfText(await _build(renamed));

      // Not a seeded name, so the vocabulary map leaves it alone in both
      // languages — it is user data, not a label.
      expect(text, contains('Tandas Blok B'));
      expect(_pdfText(await _build(renamed, l10n: _ms)),
          contains('Tandas Blok B'));
    });

    test('a name above Latin-1 degrades visibly instead of aborting',
        () async {
      const cjk = ReportsData(
        moneyIn: 100,
        moneyOut: 100,
        categoryBreakdown: [CategorySpending(name: '租金', amount: 100)],
      );

      // The built-in PDF font has no glyph for these, and the writer drops
      // them silently — which would print an empty column. The generator
      // substitutes '?' so the loss is visible, and the export still succeeds.
      final bytes = await _build(cjk);
      final text = _pdfText(bytes);

      expect(text, contains('??'), reason: 'the dropped name stays visible');
      expect(text, contains('Category Breakdown'),
          reason: 'the rest of the report still renders');
    });

    test('a name the font can draw is kept intact', () async {
      const accented = ReportsData(
        moneyIn: 100,
        moneyOut: 100,
        categoryBreakdown: [CategorySpending(name: 'Café Ünïod', amount: 100)],
      );

      expect(_pdfText(await _build(accented)), contains('Café Ünïod'));
    });
  });

  group('ReportPdfGenerator.periodLabel', () {
    test('a preset prints the chip the reader picked', () {
      expect(
        ReportPdfGenerator.periodLabel(
          filter: const ReportFilter(period: ReportPeriod.thisMonth),
          l10n: _en,
        ),
        'This month',
      );
      expect(
        ReportPdfGenerator.periodLabel(
          filter: const ReportFilter(),
          l10n: _en,
        ),
        'All time',
      );
      expect(
        ReportPdfGenerator.periodLabel(
          filter: const ReportFilter(),
          l10n: _ms,
        ),
        'Sepanjang masa',
      );
    });

    test('a custom range prints its actual dates, end day inclusive', () {
      expect(
        ReportPdfGenerator.periodLabel(
          filter: ReportFilter(
            period: ReportPeriod.custom,
            customStart: DateTime(2026, 8),
            // Exclusive: "to 20 Aug" is stored as 21 Aug.
            customEnd: DateTime(2026, 8, 21),
          ),
          l10n: _en,
        ),
        // An ASCII hyphen: the built-in font cannot draw an en dash, and would
        // drop it leaving the two dates run together.
        '1 Aug 2026 - 20 Aug 2026',
      );
    });

    test('a custom range with no dates falls back to the preset label', () {
      expect(
        ReportPdfGenerator.periodLabel(
          filter: const ReportFilter(period: ReportPeriod.custom),
          l10n: _en,
        ),
        'Custom range',
      );
    });
  });
}
