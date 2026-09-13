import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/constants/app_constants.dart';
import 'package:rental_ledger/features/reports/presentation/providers/reports_provider.dart';
import 'package:rental_ledger/features/reports/presentation/widgets/export_pdf_button.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// The Reports toolbar's Export PDF action.
///
/// The print step is injected throughout (see [PdfPresenter]) because the real
/// one opens a browser or system dialog that a widget test cannot dismiss. That
/// seam is the only thing these tests stub: everything above it — reading the
/// report, generating the document, guarding against a second tap, and turning
/// a failure into a localized message — is the shipped code path.
const ReportsData _data = ReportsData(
  totalExpenses: 350,
  totalDeposits: 800,
  moneyIn: 800,
  moneyOut: 600,
  balance: 200,
  allTimeBalance: 200,
  highestCategoryName: 'Rent',
  highestCategoryAmount: 200,
  categoryBreakdown: [CategorySpending(name: 'Rent', amount: 200)],
);

/// A record of what the button handed to the print step.
class _Presented {
  final List<Uint8List> bytes = [];
  final List<String> names = [];
}

Widget _harness({
  required ReportsData? data,
  required PdfPresenter presenter,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    child: MaterialApp(
      // Mirrors `app.dart`: the button's tooltip and error message are
      // localized, so the harness supplies the same delegates the app does.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(
        appBar: AppBar(
          actions: [ExportPdfButton(data: data, presenter: presenter)],
        ),
      ),
    ),
  );
}

IconButton _button(WidgetTester tester) =>
    tester.widget<IconButton>(find.byType(IconButton));

/// Pumps frames until [done] holds, then returns.
///
/// A frame is always pumped before the first check, so a condition that became
/// true during the tap's own microtasks (generation resolves in microtasks)
/// still gets a frame drawn for it — otherwise the tree under test is left at
/// its pre-tap state.
///
/// `pumpAndSettle` cannot be used while the busy spinner is on screen: a
/// `CircularProgressIndicator` animates forever, so nothing ever settles.
Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (done()) return;
  }
  fail('the awaited state never arrived');
}

void main() {
  testWidgets('is disabled until there is a report to export', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_harness(
      data: null,
      presenter: (_, __) async => calls++,
    ));

    // A null callback is what renders the button visibly disabled — there is
    // nothing to export while the report is loading or has failed, and the
    // page's own error state is already explaining why.
    expect(_button(tester).onPressed, isNull);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('is enabled once the report has resolved', (tester) async {
    await tester.pumpWidget(_harness(
      data: _data,
      presenter: (_, __) async {},
    ));

    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('a tap generates a PDF and hands it to the print step',
      (tester) async {
    final presented = _Presented();
    await tester.pumpWidget(_harness(
      data: _data,
      presenter: (bytes, name) async {
        presented.bytes.add(bytes);
        presented.names.add(name);
      },
    ));

    await tester.tap(find.byType(IconButton));
    await _pumpUntil(tester, () => presented.bytes.isNotEmpty);

    // Real PDF bytes, generated from the report on screen.
    expect(presented.bytes.single.length, greaterThan(1000));
    expect(presented.bytes.single.sublist(0, 5), [0x25, 0x50, 0x44, 0x46, 0x2D]);
    // The document is named for the product and the localized subtitle.
    expect(presented.names.single, '${AppConstants.appName} Financial Report');

    // The spinner is gone and the action is available again.
    await _pumpUntil(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );
    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('shows a spinner and refuses a second tap while busy',
      (tester) async {
    final gate = Completer<void>();
    final presented = _Presented();
    await tester.pumpWidget(_harness(
      data: _data,
      presenter: (bytes, name) async {
        presented.bytes.add(bytes);
        presented.names.add(name);
        await gate.future;
      },
    ));

    await tester.tap(find.byType(IconButton));
    await _pumpUntil(tester, () => presented.bytes.isNotEmpty);

    // Busy: the icon is replaced by a spinner and the action is disabled, so a
    // second tap cannot start a second export.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsNothing);
    expect(_button(tester).onPressed, isNull);

    await tester.tap(find.byType(IconButton), warnIfMissed: false);
    await tester.pump();
    expect(presented.bytes, hasLength(1),
        reason: 'a tap while busy must not start a second export');

    gate.complete();
    await _pumpUntil(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    expect(presented.bytes, hasLength(1));
  });

  testWidgets('a failure shows the localized message, not the exception',
      (tester) async {
    await tester.pumpWidget(_harness(
      data: _data,
      presenter: (_, __) async => throw StateError('net.nfet.printing: boom'),
    ));

    await tester.tap(find.byType(IconButton));
    await _pumpUntil(
      tester,
      () => find.text('Could not generate the PDF. Please try again.')
          .evaluate()
          .isNotEmpty,
    );

    // No raw exception text reaches the reader.
    expect(find.textContaining('net.nfet.printing'), findsNothing);
    expect(find.textContaining('StateError'), findsNothing);

    // The failure does not wedge the button — the reader can retry.
    await _pumpUntil(tester, () => !_isBusy(tester));
    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('a failure leaves the action usable, so the reader can retry',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_harness(
      data: _data,
      presenter: (_, __) async {
        calls++;
        throw StateError('boom $calls');
      },
    ));

    await tester.tap(find.byType(IconButton));
    await _pumpUntil(tester, () => calls == 1);
    await _pumpUntil(tester, () => !_isBusy(tester));

    // Not left on a spinner, and enabled again.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_button(tester).onPressed, isNotNull);

    // Retrying runs the whole export again rather than being swallowed.
    await tester.tap(find.byType(IconButton));
    await _pumpUntil(tester, () => calls == 2);
    await _pumpUntil(tester, () => !_isBusy(tester));
    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('the tooltip is localized', (tester) async {
    await tester.pumpWidget(_harness(
      data: _data,
      presenter: (_, __) async {},
    ));
    expect(find.byTooltip('Export PDF'), findsOneWidget);

    await tester.pumpWidget(_harness(
      data: _data,
      presenter: (_, __) async {},
      locale: const Locale('ms'),
    ));
    await tester.pump();
    expect(find.byTooltip('Eksport PDF'), findsOneWidget);
    expect(find.byTooltip('Export PDF'), findsNothing);
  });

  testWidgets('the Malay failure message is localized too', (tester) async {
    await tester.pumpWidget(_harness(
      data: _data,
      presenter: (_, __) async => throw StateError('boom'),
      locale: const Locale('ms'),
    ));

    await tester.tap(find.byType(IconButton));
    await _pumpUntil(
      tester,
      () => find.text('Tidak dapat menjana PDF. Sila cuba lagi.')
          .evaluate()
          .isNotEmpty,
    );
    expect(find.text('Could not generate the PDF. Please try again.'),
        findsNothing);
  });
}

/// True while the busy spinner is on screen.
bool _isBusy(WidgetTester tester) =>
    find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
