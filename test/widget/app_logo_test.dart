import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/constants/app_constants.dart';
import 'package:rental_ledger/core/widgets/app_logo.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Pumps [AppLogo] behind the app's own localization wiring.
///
/// The tagline is localized (the app *name* stays a constant — it is a product
/// name), so the tree needs the generated delegates exactly as `app.dart`
/// installs them.
Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('shows app name', (tester) async {
    await tester.pumpWidget(_app(const AppLogo()));

    expect(find.text('Rental Ledger'), findsOneWidget);
  });

  testWidgets('shows tagline by default', (tester) async {
    await tester.pumpWidget(_app(const AppLogo()));

    // Pins the English ARB value against the shipped constant, so the
    // migration cannot silently reword the tagline.
    expect(find.text(AppConstants.appTagline), findsOneWidget);
  });

  testWidgets('hides tagline when disabled', (tester) async {
    await tester.pumpWidget(_app(const AppLogo(showTagline: false)));

    expect(find.text(AppConstants.appTagline), findsNothing);
  });

  testWidgets('has an icon container', (tester) async {
    await tester.pumpWidget(_app(const AppLogo()));

    expect(find.byType(Container), findsWidgets);
  });
}
