import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/app/theme/app_theme.dart';
import 'package:rental_ledger/core/widgets/month_picker_field.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// "For month" fields default to the current month and are picked from a
/// month/year picker instead of typed; the stored value stays `YYYY-MM`.
void main() {
  group('period labels', () {
    test('format and parse the stored YYYY-MM form', () {
      expect(formatPeriodLabel(DateTime(2026, 3)), '2026-03');
      expect(currentPeriodLabel(DateTime(2026, 10, 7)), '2026-10');
      expect(parsePeriodLabel('2026-09'), DateTime(2026, 9));
      expect(parsePeriodLabel('2026-9'), DateTime(2026, 9));
      expect(parsePeriodLabel('2026-13'), isNull);
      expect(parsePeriodLabel('Sept'), isNull);
      expect(parsePeriodLabel(null), isNull);
    });
  });

  Future<void> pump(WidgetTester tester, TextEditingController controller) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MonthPickerField(
              controller: controller,
              labelText: 'For month (optional)',
            ),
          ),
        ),
      );

  testWidgets('tapping opens the picker; choosing a month fills the field',
      (tester) async {
    final controller = TextEditingController(text: '2026-10');
    addTearDown(controller.dispose);
    await pump(tester, controller);

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.text('Select month'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);

    // Previous year, then March.
    await tester.tap(find.byTooltip('Previous year'));
    await tester.pump();
    expect(find.text('2025'), findsOneWidget);
    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();

    expect(controller.text, '2025-03');
    expect(find.text('Select month'), findsNothing);
  });

  testWidgets('cancel leaves the value unchanged', (tester) async {
    final controller = TextEditingController(text: '2026-10');
    addTearDown(controller.dispose);
    await pump(tester, controller);

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.text, '2026-10');
  });

  testWidgets('the field stays optional: clear empties it', (tester) async {
    final controller = TextEditingController(text: '2026-10');
    addTearDown(controller.dispose);
    await pump(tester, controller);

    await tester.tap(find.byTooltip('Clear month'));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(find.byTooltip('Clear month'), findsNothing);
  });
}
