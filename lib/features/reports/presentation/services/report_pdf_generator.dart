import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/vocabulary_labels.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/reports_provider.dart';

/// Renders an already-computed [ReportsData] into a printable PDF.
///
/// ## Why this takes data instead of fetching it
///
/// The generator has no `BuildContext`, no Riverpod container and no Firestore
/// handle: it is handed the same [ReportsData] the Reports page is currently
/// displaying and turns it into bytes. That is deliberate for two reasons.
///
/// * **The PDF can never disagree with the screen.** Every figure is the value
///   the page already rendered, so a report and its export cannot drift apart.
/// * **No calculation lives here.** Money In/Out, Net Flow, the category
///   breakdown and the monthly trend are all computed by [computeReportsData].
///   This file only formats. Re-deriving any of them would create a second
///   source of truth for the household's finances.
///
/// ## Localization
///
/// Every label comes from [AppLocalizations], so the document follows the
/// language the reader has selected. Stored values are never translated here:
/// a category the household renamed prints exactly as they typed it (routed
/// through [VocabularyLabels], which passes unrecognised names through
/// untouched), and amounts go through [CurrencyUtils] so the PDF shows the same
/// currency, symbol and grouping as the app.
///
/// ## Charts become tables
///
/// The page's donut and bar charts are interactive; print is not. The
/// breakdown and the trend are therefore rendered as tables, which are
/// unambiguous on paper and page-break correctly.
class ReportPdfGenerator {
  ReportPdfGenerator._();

  // ── Print palette ───────────────────────────────────────────────────────
  //
  // The frozen light palette from `AppColors.light`, restated as PDF colours.
  // A printed page is not a themed surface — it is paper — so a report exported
  // from dark mode still prints on white with dark ink. Reading the live theme
  // here would make the same report come out of two installations looking
  // different, and would print white-on-white from dark mode. The values are
  // duplicated rather than imported because `AppColors` is a Flutter
  // `ThemeExtension` (it carries `Color`, not `PdfColor`) and importing the
  // theme here would tie the PDF to the widget layer.
  static const PdfColor _brand = PdfColor.fromInt(0xFF00897B);
  static const PdfColor _ink = PdfColor.fromInt(0xFF1D1D1D);
  static const PdfColor _muted = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _faint = PdfColor.fromInt(0xFF9E9E9E);
  static const PdfColor _line = PdfColor.fromInt(0xFFE5E7EB);
  static const PdfColor _headFill = PdfColor.fromInt(0xFFF5F5F5);
  static const PdfColor _zebra = PdfColor.fromInt(0xFFFAFBFC);
  static const PdfColor _positive = PdfColor.fromInt(0xFF28A745);
  static const PdfColor _negative = PdfColor.fromInt(0xFFDC3545);

  /// Builds the report PDF.
  ///
  /// [data] is the report exactly as displayed. [periodLabel] is the resolved
  /// period caption (see [periodLabel]). [windowed] mirrors the page's own
  /// rule for the third summary row: under a period filter it is the period's
  /// Net, otherwise it is the account's current balance.
  ///
  /// [generatedAt] is injectable so tests can pin the footer; production
  /// callers omit it and get the real clock.
  static Future<Uint8List> build({
    required ReportsData data,
    required AppLocalizations l10n,
    required String periodLabel,
    bool windowed = false,
    DateTime? generatedAt,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final document = pw.Document(
      title: '${AppConstants.appName} ${l10n.reportPdfSubtitle}',
      creator: AppConstants.appName,
    );

    final stamp = generatedAt ?? DateTime.now();
    final generated = DateFormatUtils.formatDateTime(stamp, l10n.localeName);

    // The same "is there anything to report" test the page uses, so an export
    // of the empty state reads as an empty report rather than a wall of zeros.
    final isEmpty =
        data.moneyIn == 0 && data.moneyOut == 0 && data.categoryBreakdown.isEmpty;

    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(36, 34, 36, 46),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          italic: pw.Font.helveticaOblique(),
        ),
        header: (context) =>
            context.pageNumber == 1 ? pw.SizedBox() : _runningHeader(l10n),
        footer: (context) => _footer(l10n, generated, context),
        build: (context) => [
          _titleBlock(l10n, periodLabel, generated),
          if (isEmpty)
            _emptyNotice(l10n)
          else ...[
            ..._summary(l10n, data, windowed),
            ..._insights(l10n, data),
            ..._moneyOut(l10n, data),
            ..._categoryBreakdown(l10n, data),
            ..._monthlyTrend(l10n, data),
          ],
        ],
      ),
    );

    return document.save();
  }

  /// The caption for the report's active period.
  ///
  /// Presets read as the chip the reader picked ("All time", "This month"). A
  /// custom range prints its actual dates instead, because "Custom range" alone
  /// would not tell the reader what they are looking at. [ReportFilter.customEnd]
  /// is exclusive, so the last day shown is the day before it — the same
  /// convention the range picker and the report window use.
  static String periodLabel({
    required ReportFilter filter,
    required AppLocalizations l10n,
  }) {
    if (filter.period == ReportPeriod.custom) {
      final start = filter.customStart;
      final end = filter.customEnd;
      if (start != null && end != null) {
        final lastDay = end.subtract(const Duration(days: 1));
        final from = DateFormatUtils.formatDateShort(start, l10n.localeName);
        final to = DateFormatUtils.formatDateShort(lastDay, l10n.localeName);
        // A plain hyphen, not an en dash. The built-in PDF font cannot draw
        // U+2013 and would drop it silently, printing "…2026  20 Sep…" with the
        // separator missing. See [_safe].
        return '$from - $to';
      }
    }
    return filter.period.labelFor(l10n);
  }

  // ── Page furniture ──────────────────────────────────────────────────────

  /// The first-page title block: product name, localized subtitle, and the two
  /// facts a reader needs to date the document.
  static pw.Widget _titleBlock(
    AppLocalizations l10n,
    String periodLabel,
    String generated,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          // The product name is a proper noun and is never translated — it is
          // carried verbatim from `AppConstants` in both locales.
          AppConstants.appName,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: _brand,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          _safe(l10n.reportPdfSubtitle),
          style: const pw.TextStyle(fontSize: 11.5, color: _muted),
        ),
        pw.SizedBox(height: 12),
        pw.Container(height: 2, width: 46, color: _brand),
        pw.SizedBox(height: 14),
        _factRow(l10n.reportPdfPeriod, periodLabel),
        pw.SizedBox(height: 4),
        // The generated-on message is a whole sentence with the stamp embedded,
        // so it renders on its own line rather than as a label/value pair.
        pw.Text(
          _safe(l10n.reportPdfGeneratedOn(generated)),
          style: const pw.TextStyle(fontSize: 10, color: _faint),
        ),
      ],
    );
  }

  /// A `label — value` line in the title block.
  static pw.Widget _factRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 92,
          child: pw.Text(
            _safe(label),
            style: const pw.TextStyle(fontSize: 10, color: _faint),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            _safe(value),
            style: pw.TextStyle(
              fontSize: 10,
              color: _ink,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Repeats just enough of the title on continuation pages to identify them.
  static pw.Widget _runningHeader(AppLocalizations l10n) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.7)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            AppConstants.appName,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: _brand,
            ),
          ),
          pw.Text(
            _safe(l10n.reportPdfSubtitle),
            style: const pw.TextStyle(fontSize: 9.5, color: _muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(
    AppLocalizations l10n,
    String generated,
    pw.Context context,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _line, width: 0.7)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            _safe(l10n.reportPdfGeneratedOn(generated)),
            style: const pw.TextStyle(fontSize: 8.5, color: _faint),
          ),
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8.5, color: _faint),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20, bottom: 8),
      child: pw.Row(
        children: [
          pw.Container(width: 3, height: 13, color: _brand),
          pw.SizedBox(width: 8),
          pw.Text(
            _safe(title),
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _emptyNotice(AppLocalizations l10n) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 24),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _headFill,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        _safe(l10n.reportPdfNoData),
        style: const pw.TextStyle(fontSize: 10.5, color: _muted),
      ),
    );
  }

  // ── Sections ────────────────────────────────────────────────────────────

  /// Summary: the page's In/Out/Net row, plus the expense/deposit/net-flow
  /// figures the report is expected to carry.
  static List<pw.Widget> _summary(
    AppLocalizations l10n,
    ReportsData data,
    bool windowed,
  ) {
    final rows = <List<String>>[
      [l10n.reportMoneyIn, _money(data.moneyIn, l10n)],
      [l10n.reportMoneyOut, _money(data.moneyOut, l10n)],
      [
        windowed ? l10n.labelNet : l10n.reportCurrentBalance,
        _money(data.balance, l10n),
      ],
      [l10n.reportPdfTotalExpenses, _money(data.totalExpenses, l10n)],
      [l10n.reportPdfTotalDeposits, _money(data.totalDeposits, l10n)],
      [l10n.reportPdfNetFlow, _money(data.netFlow, l10n)],
    ];

    return [
      _sectionTitle(l10n.reportPdfSummary),
      // The Net / balance line is the figure a reader looks for first, so it is
      // emphasised and coloured by sign — green when the account is in credit,
      // red when it is overdrawn, matching the page's summary box.
      _labelValueTable(
        rows,
        emphasiseRow: 2,
        emphasiseColor: data.balance >= 0 ? _positive : _negative,
      ),
      // Under a period filter the third row above is the period's Net, not the
      // account's real balance — so the true all-time figure is called out, the
      // same way the page does beneath its summary row.
      if (windowed) ...[
        pw.SizedBox(height: 6),
        pw.Text(
          _safe(l10n.reportCentralBalanceAllTime(_money(data.allTimeBalance, l10n))),
          style: const pw.TextStyle(fontSize: 9, color: _faint),
        ),
      ],
    ];
  }

  /// The page's insight cards, as rows.
  static List<pw.Widget> _insights(AppLocalizations l10n, ReportsData data) {
    // A seeded default category prints in the reader's language; a category the
    // household renamed prints their own words, untouched.
    final highestName = VocabularyLabels.categoryOrNull(
      l10n: l10n,
      name: data.highestCategoryName,
    );

    final rows = <List<String>>[
      [
        l10n.reportHighestExpenseCategory,
        highestName == null
            ? '—'
            : '$highestName · ${_money(data.highestCategoryAmount, l10n)}',
      ],
      [l10n.reportLargestExpenseClaim, _money(data.largestExpense, l10n)],
      [l10n.reportExpenseReimbursements, _money(data.totalExpenses, l10n)],
      [l10n.reportPendingReimbursements, _money(data.pendingReimbursements, l10n)],
      [l10n.reportAverageMonthlyExpense, _money(data.averageMonthlyExpense, l10n)],
      [l10n.reportAverageDeposit, _money(data.avgDeposit, l10n)],
      [l10n.reportLargestDeposit, _money(data.largestDeposit, l10n)],
      [l10n.reportBillsPaid, '${data.billsPaid}'],
      [l10n.reportBillsPending, '${data.billsPending}'],
    ];

    return [_sectionTitle(l10n.reportInsights), _labelValueTable(rows)];
  }

  /// "Where the Money Goes" — the stacked bar as a table. Only shown when money
  /// actually went out, matching the page's own rule.
  static List<pw.Widget> _moneyOut(AppLocalizations l10n, ReportsData data) {
    final breakdown = data.moneyOutBreakdown;
    if (breakdown.total <= 0) return const [];

    final buckets = <({String label, double amount})>[
      (label: l10n.reportMoneyOutReimbursements, amount: breakdown.expenseReimbursements),
      (label: l10n.reportMoneyOutDirectPayments, amount: breakdown.directPayments),
      (label: l10n.reportMoneyOutBillPayments, amount: breakdown.billPayments),
      (label: l10n.reportMoneyOutAdjustments, amount: breakdown.negativeAdjustments),
      (label: l10n.reportMoneyOutOther, amount: breakdown.other),
    ].where((b) => b.amount > 0).toList();

    return [
      _sectionTitle(l10n.reportWhereMoneyGoes),
      _dataTable(
        headers: [l10n.labelCategory, l10n.labelAmount, l10n.reportPdfShare],
        rows: [
          for (final b in buckets)
            [
              b.label,
              _money(b.amount, l10n),
              _share(b.amount, breakdown.total),
            ],
          [
            l10n.labelTotal,
            _money(breakdown.total, l10n),
            _share(breakdown.total, breakdown.total),
          ],
        ],
        alignments: const [
          pw.Alignment.centerLeft,
          pw.Alignment.centerRight,
          pw.Alignment.centerRight,
        ],
      ),
    ];
  }

  /// Category breakdown, highest first — the donut as a table.
  static List<pw.Widget> _categoryBreakdown(
    AppLocalizations l10n,
    ReportsData data,
  ) {
    final breakdown = data.categoryBreakdown;
    if (breakdown.isEmpty) return const [];

    final total = breakdown.fold<double>(0, (sum, c) => sum + c.amount);

    return [
      _sectionTitle(l10n.reportCategoryBreakdown),
      _dataTable(
        headers: [l10n.labelCategory, l10n.labelAmount, l10n.reportPdfShare],
        rows: [
          for (final c in breakdown)
            [
              // The stored name reaches the PDF through the same vocabulary
              // mapping the legend uses. A renamed category keeps the user's
              // exact text — it is never overwritten or translated.
              VocabularyLabels.category(l10n: l10n, name: c.name),
              _money(c.amount, l10n),
              _share(c.amount, total),
            ],
          [
            l10n.labelTotal,
            _money(total, l10n),
            _share(total, total),
          ],
        ],
        alignments: const [
          pw.Alignment.centerLeft,
          pw.Alignment.centerRight,
          pw.Alignment.centerRight,
        ],
      ),
    ];
  }

  /// Monthly trend — the bar chart as a table. Months arrive already labelled in
  /// the reader's language, because [computeReportsData] formats them through
  /// the locale it was given.
  static List<pw.Widget> _monthlyTrend(AppLocalizations l10n, ReportsData data) {
    final trend = data.monthlyTrend;
    if (trend.isEmpty) return const [];

    final totalIn = trend.fold<double>(0, (sum, m) => sum + m.moneyIn);
    final totalOut = trend.fold<double>(0, (sum, m) => sum + m.moneyOut);

    return [
      _sectionTitle(l10n.reportMonthlyTrend),
      _dataTable(
        headers: [
          l10n.reportPdfMonth,
          l10n.reportMoneyIn,
          l10n.reportMoneyOut,
          l10n.labelNet,
        ],
        rows: [
          for (final m in trend)
            [
              m.month,
              _money(m.moneyIn, l10n),
              _money(m.moneyOut, l10n),
              _money(m.net, l10n),
            ],
          [
            l10n.labelTotal,
            _money(totalIn, l10n),
            _money(totalOut, l10n),
            _money(totalIn - totalOut, l10n),
          ],
        ],
        alignments: const [
          pw.Alignment.centerLeft,
          pw.Alignment.centerRight,
          pw.Alignment.centerRight,
          pw.Alignment.centerRight,
        ],
      ),
    ];
  }

  // ── Table primitives ────────────────────────────────────────────────────

  /// A two-column label/value table — the shape every insight and summary row
  /// shares.
  ///
  /// [emphasiseRow] is drawn in [emphasiseColor] and bolded: the summary uses it
  /// for the Net / Current Balance line, the one figure the reader looks for
  /// first.
  static pw.Widget _labelValueTable(
    List<List<String>> rows, {
    int? emphasiseRow,
    PdfColor emphasiseColor = _brand,
  }) {
    return _dataTable(
      rows: rows,
      alignments: const [pw.Alignment.centerLeft, pw.Alignment.centerRight],
      flexes: const [3.0, 2.0],
      emphasiseRow: emphasiseRow,
      emphasiseColor: emphasiseColor,
    );
  }

  /// The one table builder behind every section.
  ///
  /// Written against `pw.Table` rather than `TableHelper.fromTextArray` because
  /// the closing Total row has to carry its own weight (bold, tinted) and
  /// `TableHelper`'s `OnCellFormat` — `String Function(int, dynamic)` — returns
  /// a string, so it can format text but cannot restyle a row.
  ///
  /// The last row is always treated as the total: tinted, bolded, and separated
  /// from the line items above it.
  static pw.Widget _dataTable({
    List<String> headers = const [],
    required List<List<String>> rows,
    required List<pw.AlignmentGeometry> alignments,
    List<double>? flexes,
    int? emphasiseRow,
    PdfColor emphasiseColor = _ink,
  }) {
    if (rows.isEmpty) return pw.SizedBox();
    final lastIndex = rows.length - 1;
    final widths = <int, pw.TableColumnWidth>{
      for (int c = 0; c < alignments.length; c++)
        c: pw.FlexColumnWidth((flexes ?? _defaultFlexes(alignments.length))[c]),
    };

    return pw.Table(
      columnWidths: widths,
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
      ),
      children: [
        if (headers.isNotEmpty)
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _headFill),
            children: [
              for (int c = 0; c < headers.length; c++)
                _cell(
                  headers[c],
                  align: alignments[c],
                  color: _muted,
                  bold: true,
                ),
            ],
          ),
        for (int r = 0; r < rows.length; r++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: r == lastIndex ? _headFill : (r.isEven ? _zebra : null),
            ),
            children: [
              for (int c = 0; c < rows[r].length; c++)
                _cell(
                  rows[r][c],
                  align: alignments[c],
                  bold: r == lastIndex || r == emphasiseRow,
                  color: r == emphasiseRow ? emphasiseColor : _ink,
                ),
            ],
          ),
      ],
    );
  }

  /// A leading label column and equal-width value columns.
  static List<double> _defaultFlexes(int columns) =>
      [3.0, for (int c = 1; c < columns; c++) 2.0];

  static pw.Widget _cell(
    String text, {
    required pw.AlignmentGeometry align,
    PdfColor color = _ink,
    bool bold = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      alignment: align,
      child: pw.Text(
        _safe(text),
        style: pw.TextStyle(
          fontSize: 9.5,
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // ── Value formatting ────────────────────────────────────────────────────

  /// Money, formatted by the app's own currency utility so the PDF agrees with
  /// every other amount in the product — same symbol, same currency choice,
  /// same locale grouping. Stored amounts are never altered.
  static String _money(double amount, AppLocalizations l10n) =>
      CurrencyUtils.format(amount, localeCode: l10n.localeName);

  /// A whole-percent share, matching the page's legend.
  static String _share(double amount, double total) =>
      total <= 0 ? '0%' : '${((amount / total) * 100).toStringAsFixed(0)}%';

  /// Replaces any character the built-in PDF font cannot draw.
  ///
  /// The base-14 PDF fonts carry a Latin-1 glyph set, so a character above
  /// U+00FF has no glyph to draw. The `pdf` package does not throw on one — it
  /// drops the glyph, logs a console warning, and renders the rest of the line.
  /// That is the worse failure of the two: a category named in Chinese would
  /// print as an empty column, with nothing on the page to say a name was ever
  /// there. Substituting `?` keeps the loss visible, which is what a reader
  /// needs in order to distrust the row rather than misread it.
  ///
  /// The boundary is exactly U+00FF, verified against the font's real
  /// behaviour: `é`, `ü`, `°` and `£` draw, while U+2013, U+2019, `€` and any
  /// CJK or kana character are dropped. Everything the app itself authors
  /// (labels, month names, currency, dates) is ASCII in both supported locales,
  /// so in practice this only touches a user-typed name in a script the
  /// built-in font does not cover. Embedding a Unicode font would print those
  /// names intact; see the known limitations recorded with this feature.
  static String _safe(String value) {
    const replacement = '?';
    // The overwhelmingly common case is already-safe text, so it is returned
    // untouched without building a new string.
    var safe = true;
    for (final rune in value.runes) {
      if (rune < 0x20 || rune > 0xFF || rune == 0x7F) {
        safe = false;
        break;
      }
    }
    if (safe) return value;

    final out = StringBuffer();
    for (final rune in value.runes) {
      final printable = rune >= 0x20 && rune <= 0xFF && rune != 0x7F;
      out.write(printable ? String.fromCharCode(rune) : replacement);
    }
    return out.toString();
  }
}
