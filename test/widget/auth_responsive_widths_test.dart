import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/services/firebase_service.dart';
import 'package:rental_ledger/features/authentication/presentation/pages/forgot_password_page.dart';
import 'package:rental_ledger/features/authentication/presentation/pages/login_page.dart';
import 'package:rental_ledger/features/authentication/presentation/pages/register_page.dart';
import 'package:rental_ledger/features/members/presentation/pages/create_house_page.dart';
import 'package:rental_ledger/features/members/presentation/pages/join_house_page.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Sweeps the responsive auth/onboarding pages across the widths the Web/PWA
/// responsive work targets (phones, tablets, desktops, large monitors) and
/// fails if any page overflows at any width. This is the automated equivalent
/// of manually resizing the browser during a responsive review.
///
/// The breakpoints sit at 600/840/1200, so these widths exercise each class:
/// compact (360, 414), medium (600, 768, 834), expanded (840, 1024), and
/// extraLarge (1280, 1440, 1920).

const _widths = <double>[360, 414, 600, 768, 834, 840, 1024, 1280, 1440, 1920];

const _pages = <String, Widget>{
  'Login': LoginPage(),
  'Register': RegisterPage(),
  'ForgotPassword': ForgotPasswordPage(),
  'CreateHouse': CreateHousePage(),
  'JoinHouse': JoinHousePage(),
};

Widget _harness(Widget child) {
  return ProviderScope(
    overrides: [
      firebaseInitResultProvider.overrideWithValue(
        const FirebaseInitResult(false, 'Firebase not available in test'),
      ),
    ],
    child: MaterialApp(
      // Mirrors `app.dart`: every page in the sweep renders AppLogo, whose
      // tagline is localized, so the tree needs the generated delegates.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  for (final entry in _pages.entries) {
    for (final width in _widths) {
      testWidgets('${entry.key} renders without overflow at ${width}px',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_harness(entry.value));
        await tester.pump(); // Settle async providers.

        expect(tester.takeException(), isNull,
            reason: '${entry.key} overflowed at $width px');
      });
    }
  }
}
