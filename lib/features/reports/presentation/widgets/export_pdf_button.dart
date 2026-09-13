import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/reports_provider.dart';
import '../services/report_pdf_generator.dart';

/// Hands generated PDF bytes to the platform's print/PDF flow.
///
/// The default implementation is [ExportPdfButton.printPdf] — the browser's
/// print dialog on Web, the system print sheet elsewhere. It is a parameter
/// only so tests can exercise a *successful* export without a platform channel;
/// production callers never pass one.
typedef PdfPresenter = Future<void> Function(Uint8List bytes, String name);

/// The Reports app-bar action that exports the current report as a PDF.
///
/// The button owns exactly three concerns — when it may run, what it hands to
/// the generator, and what the reader sees if that fails. The document itself
/// is built by [ReportPdfGenerator], which knows nothing about widgets.
///
/// [data] is the report currently on screen. It is null while the report is
/// still loading or has failed, and the action is disabled then: there is
/// nothing to export, and the page's own error state is already explaining why.
class ExportPdfButton extends ConsumerStatefulWidget {
  const ExportPdfButton({super.key, required this.data, this.presenter});

  /// The report to export, exactly as displayed.
  final ReportsData? data;

  /// Overrides the print step. Defaults to [printPdf].
  final PdfPresenter? presenter;

  /// Opens the platform's print / save-as-PDF flow with [bytes].
  ///
  /// The page format is A4, which is what [ReportPdfGenerator] lays the
  /// document out for and what `Printing.layoutPdf` already defaults to
  /// (`PdfPageFormat.standard` is A4). Passing it again would be redundant, so
  /// it is left to the default rather than restated.
  ///
  /// The same bytes are returned for whatever sheet size the platform reports:
  /// the layout paginates, so a differently-sized page reflows instead of
  /// clipping.
  ///
  /// On Web this raises the browser's own print dialog, which is where a reader
  /// saves the report as a PDF. The app never writes to the filesystem itself,
  /// so no native file API is assumed — and no `dart:html`/`dart:io` import is
  /// needed, which is what keeps this working on both Web and mobile.
  static Future<void> printPdf(Uint8List bytes, String name) {
    return Printing.layoutPdf(
      name: name,
      onLayout: (_) => bytes,
    );
  }

  @override
  ConsumerState<ExportPdfButton> createState() => _ExportPdfButtonState();
}

class _ExportPdfButtonState extends ConsumerState<ExportPdfButton> {
  /// True from the moment an export starts until it finishes or fails.
  ///
  /// Doubles as the duplicate guard: the button is disabled while it is set, so
  /// a second tap cannot start a second export, and the `_export` entry check
  /// covers a programmatic re-entry.
  bool _busy = false;

  bool get _enabled => widget.data != null && !_busy;

  Future<void> _export() async {
    final data = widget.data;
    if (data == null || _busy) return;

    // Everything read off the widget tree happens before the first `await`.
    // Generation can take a moment and the print dialog can take much longer,
    // and the reader is free to navigate away in the meantime — so what the
    // document needs is captured now rather than looked up afterwards.
    final l10n = AppLocalizations.of(context);
    final filter = ref.read(reportFilterProvider);

    setState(() => _busy = true);
    try {
      final bytes = await ReportPdfGenerator.build(
        data: data,
        l10n: l10n,
        periodLabel: ReportPdfGenerator.periodLabel(filter: filter, l10n: l10n),
        // Mirrors the page: under a period filter the summary's third figure is
        // the period's Net, not the account's real balance.
        windowed: resolveReportWindow(filter) != null,
      );
      await (widget.presenter ?? ExportPdfButton.printPdf)(
        bytes,
        '${AppConstants.appName} ${l10n.reportPdfSubtitle}',
      );
    } catch (_) {
      // Whatever went wrong — a font the encoder could not map, a print dialog
      // the browser refused — the reader gets a localized sentence. The
      // exception itself is deliberately not surfaced: it is developer-facing
      // text that would mean nothing here, and may name internals.
      if (mounted) {
        SnackbarUtils.showError(context, l10n.reportPdfFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined),
      // A null callback is what makes the button visibly disabled while the
      // report loads and while an export is already running.
      onPressed: _enabled ? _export : null,
      tooltip: l10n.actionExportPdf,
    );
  }
}
