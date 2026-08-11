import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/constants/app_constants.dart';
import 'package:rental_ledger/core/widgets/app_logo.dart';

void main() {
  testWidgets('shows app name', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLogo())),
    );

    expect(find.text('Rental Ledger'), findsOneWidget);
  });

  testWidgets('shows tagline by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLogo())),
    );

    expect(find.text(AppConstants.appTagline), findsOneWidget);
  });

  testWidgets('hides tagline when disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLogo(showTagline: false))),
    );

    expect(find.text(AppConstants.appTagline), findsNothing);
  });

  testWidgets('has an icon container', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLogo())),
    );

    expect(find.byType(Container), findsWidgets);
  });
}
