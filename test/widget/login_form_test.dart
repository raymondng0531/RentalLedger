import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/services/firebase_service.dart';
import 'package:rental_ledger/features/authentication/presentation/pages/login_page.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

Widget _buildLogin() {
  return ProviderScope(
    overrides: [
      firebaseInitResultProvider.overrideWithValue(
        const FirebaseInitResult(false, 'Firebase not available in test'),
      ),
    ],
    child: const MaterialApp(
      // Mirrors `app.dart`: LoginPage renders AppLogo, whose tagline is
      // localized, so the tree needs the generated delegates.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginPage(),
    ),
  );
}

void main() {
  testWidgets('shows email and password fields', (tester) async {
    await tester.pumpWidget(_buildLogin());
    await tester.pump(); // Settle async provider

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
  });

  testWidgets('validates empty email', (tester) async {
    await tester.pumpWidget(_buildLogin());
    await tester.pump();

    await tester.tap(find.text('Sign In').first);
    await tester.pump();

    expect(find.text('Please enter your email'), findsOneWidget);
  });

  testWidgets('validates invalid email', (tester) async {
    await tester.pumpWidget(_buildLogin());
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'notanemail');
    await tester.tap(find.text('Sign In').first);
    await tester.pump();

    expect(find.text('Please enter a valid email'), findsOneWidget);
  });

  testWidgets('validates short password', (tester) async {
    await tester.pumpWidget(_buildLogin());
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'user@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
    await tester.tap(find.text('Sign In').first);
    await tester.pump();

    expect(
      find.textContaining('Password must be at least'),
      findsOneWidget,
    );
  });

  testWidgets('has forgot password link', (tester) async {
    await tester.pumpWidget(_buildLogin());
    await tester.pump();

    expect(find.text('Forgot Password?'), findsOneWidget);
  });
}
