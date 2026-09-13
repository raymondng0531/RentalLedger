import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/app/theme/app_colors.dart';
import 'package:rental_ledger/app/theme/app_theme.dart';
import 'package:rental_ledger/core/services/firebase_service.dart';
import 'package:rental_ledger/core/widgets/app_logo.dart';
import 'package:rental_ledger/features/authentication/presentation/pages/forgot_password_page.dart';
import 'package:rental_ledger/features/authentication/presentation/pages/login_page.dart';
import 'package:rental_ledger/features/authentication/presentation/pages/register_page.dart';
import 'package:rental_ledger/features/dashboard/domain/entities/activity_item.dart';
import 'package:rental_ledger/features/dashboard/presentation/widgets/pending_items_section.dart';
import 'package:rental_ledger/features/dashboard/presentation/widgets/summary_card.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Phase 3B — App Shell + Authentication + Dashboard.
///
/// Two things are being proved here, and they are different in kind:
///
/// 1. **Parity.** Every colour Phase 3B replaced resolves, in light mode, to
///    the exact ARGB value V1.0 shipped — asserted against the legacy
///    `AppTheme` constant the old code read, so a future edit to the palette
///    cannot silently re-colour the shipped light theme.
/// 2. **Dark legibility.** The same widgets, pumped over `AppTheme.darkTheme`,
///    paint foregrounds that clear WCAG AA against what they sit on. This is
///    the half that was previously broken — AppLogo's white glyph measured
///    ~2.4:1 on the lightened dark teal.
///
/// Widgets are pumped through the real theme pair rather than a bare
/// `MaterialApp`, so `context.colors` resolves through `ThemeData.extensions`
/// exactly as it does in the app.

/// WCAG contrast ratio: `(lighter + 0.05) / (darker + 0.05)`.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

/// `MaterialApp` swaps themes through an `AnimatedTheme`, so re-pumping the
/// same element in the other mode leaves the *old* palette on screen until the
/// cross-fade finishes. These tests switch modes inside a single test, so the
/// animation has to be run out before anything is asserted — and
/// `pumpAndSettle` is unusable here because several of these widgets contain
/// indefinitely-repeating animations.
Future<void> _pumpThemed(
  WidgetTester tester,
  Widget child,
  ThemeData theme,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The auth pages build a `Scaffold` themselves, so they are the `home`.
///
/// Delegates mirror `app.dart` — AppLogo's tagline is localized, and the auth
/// pages render it.
Future<void> _pumpPage(
  WidgetTester tester,
  Widget page,
  ThemeData theme,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // The auth providers short-circuit to "unavailable" instead of
        // reaching for a Firebase instance that does not exist under test.
        // Same harness as `login_form_test.dart`.
        firebaseInitResultProvider.overrideWithValue(
          const FirebaseInitResult(false, 'Firebase not available in test'),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

// ── AppLogo finders ──

Finder _logoGlyph() =>
    find.descendant(of: find.byType(AppLogo), matching: find.byIcon(Icons.home_rounded));

Color _logoGlyphColor(WidgetTester tester) =>
    tester.widget<Icon>(_logoGlyph()).color!;

/// The rounded tile the glyph is knocked out of — the nearest `Container`
/// ancestor of the icon.
BoxDecoration _logoTile(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.ancestor(of: _logoGlyph(), matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  // ──────────────────────────────────────────────
  // AppLogo — the spec's explicit contrast fix
  // ──────────────────────────────────────────────
  group('AppLogo', () {
    testWidgets('light mode is byte-identical to V1.0', (tester) async {
      await _pumpThemed(tester, const AppLogo(), AppTheme.lightTheme);

      // Teal tile, white glyph — the shipped mark, unchanged.
      expect(
        _logoTile(tester).color!.toARGB32(),
        AppTheme.primaryGreen.toARGB32(),
      );
      expect(_logoGlyphColor(tester).toARGB32(), 0xFFFFFFFF);
      expect(_logoGlyphColor(tester), AppColors.light.onPrimary);
    });

    testWidgets('dark mode inks the glyph for contrast', (tester) async {
      await _pumpThemed(tester, const AppLogo(), AppTheme.darkTheme);

      final glyph = _logoGlyphColor(tester);
      final tile = _logoTile(tester).color!;

      expect(tile, AppColors.dark.primary);
      expect(glyph, AppColors.dark.onPrimary);
      expect(
        _contrast(glyph, tile),
        greaterThanOrEqualTo(4.5),
        reason: 'the logo glyph is the app mark — it must clear AA',
      );
    });

    testWidgets('dark mode no longer paints a white glyph', (tester) async {
      await _pumpThemed(tester, const AppLogo(), AppTheme.darkTheme);

      final glyph = _logoGlyphColor(tester);

      expect(glyph, isNot(Colors.white));
      // Documents the defect this replaced: white on the dark palette's
      // lightened teal, which is the ~1.9:1 the spec called out.
      expect(
        _contrast(Colors.white, AppColors.dark.primary),
        lessThan(4.5),
      );
    });

    testWidgets('the app name follows the palette in both modes',
        (tester) async {
      await _pumpThemed(tester, const AppLogo(), AppTheme.lightTheme);
      expect(
        tester.widget<Text>(find.text('Rental Ledger')).style!.color,
        AppColors.light.primary,
      );

      await _pumpThemed(tester, const AppLogo(), AppTheme.darkTheme);
      expect(
        tester.widget<Text>(find.text('Rental Ledger')).style!.color,
        AppColors.dark.primary,
      );
    });

    testWidgets('renders at every size in both modes without throwing',
        (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        for (final size in AppLogoSize.values) {
          await _pumpThemed(tester, AppLogo(size: size), theme);
          expect(tester.takeException(), isNull);
        }
      }
    });

    test('the light glyph ratio is V1.0s, not a Phase 3B regression', () {
      // White on #00897B measures ~4.3:1 — just under AA. That is what V1.0
      // ships and Phase 3B is not permitted to change it, so the test pins the
      // value rather than the ratio. Dark mode is the half that had to clear
      // AA, and does (see the widget test above).
      expect(AppColors.light.onPrimary.toARGB32(), 0xFFFFFFFF);
      expect(AppColors.light.primary.toARGB32(), AppTheme.primaryGreen.toARGB32());
    });
  });

  // ──────────────────────────────────────────────
  // Authentication
  // ──────────────────────────────────────────────
  group('authentication pages', () {
    testWidgets('LoginPage follows the theme', (tester) async {
      await _pumpPage(tester, const LoginPage(), AppTheme.lightTheme);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        AppColors.light.surface,
      );

      await _pumpPage(tester, const LoginPage(), AppTheme.darkTheme);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        AppColors.dark.surface,
      );
    });

    testWidgets('RegisterPage follows the theme', (tester) async {
      await _pumpPage(tester, const RegisterPage(), AppTheme.lightTheme);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        AppColors.light.surface,
      );

      await _pumpPage(tester, const RegisterPage(), AppTheme.darkTheme);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        AppColors.dark.surface,
      );
    });

    testWidgets('ForgotPasswordPage themes both its scaffold and app bar',
        (tester) async {
      await _pumpPage(tester, const ForgotPasswordPage(), AppTheme.lightTheme);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        AppColors.light.surface,
      );
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        AppColors.light.surface,
      );

      await _pumpPage(tester, const ForgotPasswordPage(), AppTheme.darkTheme);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        AppColors.dark.surface,
      );
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        AppColors.dark.surface,
      );
    });

    /// The social buttons carry an explicit foreground and border, so they are
    /// the auth pages' clearest case of hardcoded colour that had to move.
    ///
    /// `bySubtype`, not `byType`: `OutlinedButton.icon` builds a private
    /// `_OutlinedButtonWithIcon` subclass, and `find.byType` matches the exact
    /// runtime type, so it would find nothing here.
    OutlinedButton googleButton(WidgetTester tester) =>
        tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text('Continue with Google'),
            matching: find.bySubtype<OutlinedButton>(),
          ),
        );

    testWidgets('the Google button resolves to palette tokens',
        (tester) async {
      const enabled = <WidgetState>{};

      await _pumpPage(tester, const LoginPage(), AppTheme.lightTheme);
      var style = googleButton(tester).style!;
      expect(style.foregroundColor!.resolve(enabled), AppColors.light.textPrimary);
      expect(style.side!.resolve(enabled)!.color, AppColors.light.divider);

      await _pumpPage(tester, const LoginPage(), AppTheme.darkTheme);
      style = googleButton(tester).style!;
      expect(style.foregroundColor!.resolve(enabled), AppColors.dark.textPrimary);
      expect(style.side!.resolve(enabled)!.color, AppColors.dark.divider);
    });

    test('the primary CTA ink is unchanged in light and clears AA in dark', () {
      // Light: the FilledButton fill is `primary` and its ink is `onPrimary`,
      // both exactly as V1.0 — so the loading spinner's `Colors.white` swap is
      // a no-op in light mode.
      expect(AppTheme.lightTheme.colorScheme.primary, AppColors.light.primary);
      expect(
        AppTheme.lightTheme.colorScheme.onPrimary,
        AppColors.light.onPrimary,
      );
      expect(AppColors.light.onPrimary.toARGB32(), 0xFFFFFFFF);

      // Dark: the fill lightens, so the ink must flip with it.
      expect(
        _contrast(AppColors.dark.onPrimary, AppColors.dark.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(Colors.white, AppColors.dark.primary),
        lessThan(4.5),
        reason: 'this is why the spinner could not stay a literal white',
      );
    });

    test('the auth app bar uses an opaque surface, not the frosted bar fill',
        () {
      // The pages override the app bar to opaque white. `surface` is opaque in
      // both palettes; `glassBarFill` is deliberately translucent and would
      // have altered the shipped light bar.
      expect(AppColors.light.surface.a, 1.0);
      expect(AppColors.dark.surface.a, 1.0);
      expect(AppColors.light.glassBarFill.a, lessThan(1.0));
    });

    test('the reset page title ink matches the app bar theme it now uses', () {
      // `reset_password_page.dart` was the one screen inking a literal
      // `Colors.black`. It now reads the same token every other app bar uses.
      expect(
        AppTheme.lightTheme.appBarTheme.foregroundColor,
        AppColors.light.textPrimary,
      );
      expect(
        AppTheme.darkTheme.appBarTheme.foregroundColor,
        AppColors.dark.textPrimary,
      );
      expect(
        _contrast(AppColors.dark.textPrimary, AppColors.dark.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  // ──────────────────────────────────────────────
  // Dashboard
  // ──────────────────────────────────────────────
  group('SummaryCard', () {
    const icon = Icons.trending_up_rounded;

    Future<void> pump(
      WidgetTester tester,
      ThemeData theme, {
      Color? iconBackground,
      bool isLoading = false,
    }) =>
        _pumpThemed(
          tester,
          SummaryCard(
            label: 'Money In',
            amount: 1234.56,
            icon: icon,
            iconBackground: iconBackground,
            isLoading: isLoading,
          ),
          theme,
        );

    testWidgets('defaults to the palette primary in both modes',
        (tester) async {
      await pump(tester, AppTheme.lightTheme);
      expect(tester.widget<Icon>(find.byIcon(icon)).color, AppColors.light.primary);

      await pump(tester, AppTheme.darkTheme);
      expect(tester.widget<Icon>(find.byIcon(icon)).color, AppColors.dark.primary);
    });

    testWidgets('honours a caller-supplied semantic accent', (tester) async {
      // The dashboard passes success / error / pending for Money In, Money Out
      // and Pending. Those are semantic tokens now, not literals.
      await pump(tester, AppTheme.lightTheme, iconBackground: AppColors.light.success);
      expect(tester.widget<Icon>(find.byIcon(icon)).color, AppColors.light.success);

      await pump(tester, AppTheme.darkTheme, iconBackground: AppColors.dark.error);
      expect(tester.widget<Icon>(find.byIcon(icon)).color, AppColors.dark.error);
    });

    testWidgets('the loading placeholder follows the palette', (tester) async {
      Future<bool> hasPlaceholder(ThemeData theme) async {
        await pump(tester, theme, isLoading: true);
        final expected = theme.extension<AppColors>()!.placeholderTint.withAlpha(30);
        return tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(SummaryCard),
                matching: find.byType(Container),
              ),
            )
            .any((c) => (c.decoration as BoxDecoration?)?.color == expected);
      }

      expect(await hasPlaceholder(AppTheme.lightTheme), isTrue);
      expect(await hasPlaceholder(AppTheme.darkTheme), isTrue);
    });

    testWidgets('the label uses the secondary text tone in both modes',
        (tester) async {
      await pump(tester, AppTheme.lightTheme);
      expect(
        tester.widget<Text>(find.text('Money In')).style!.color,
        AppColors.light.textSecondary,
      );

      await pump(tester, AppTheme.darkTheme);
      expect(
        tester.widget<Text>(find.text('Money In')).style!.color,
        AppColors.dark.textSecondary,
      );
    });

    test('the placeholder tint is the shipped grey, exactly', () {
      // `Colors.grey.withAlpha(30)` → `placeholderTint.withAlpha(30)` is a
      // byte-for-byte no-op in light mode, which is what makes the swap safe.
      expect(AppColors.light.placeholderTint.toARGB32(), 0xFF9E9E9E);
      expect(
        AppColors.light.placeholderTint.withAlpha(30).toARGB32(),
        Colors.grey.withAlpha(30).toARGB32(),
      );
      // …and is lifted in dark mode so it still reads on the dark card.
      expect(
        AppColors.dark.placeholderTint.computeLuminance(),
        greaterThan(AppColors.light.placeholderTint.computeLuminance()),
      );
    });
  });

  group('PendingItemsSection', () {
    ActivityItem item({String? status}) => ActivityItem(
          id: 'e1',
          type: 'expense',
          title: 'Laundry Detergent',
          amount: 42.5,
          date: DateTime(2026, 3, 4),
          status: status,
          categoryId: 'household',
          paymentSource: 'personal',
        );

    Future<void> pump(
      WidgetTester tester,
      ThemeData theme,
      List<ActivityItem> items,
    ) =>
        _pumpThemed(
          tester,
          PendingItemsSection(
            items: items,
            categoryMap: const {'household': 'Household'},
          ),
          theme,
        );

    testWidgets('the empty state follows the theme', (tester) async {
      await pump(tester, AppTheme.lightTheme, const []);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.task_alt_rounded)).color,
        AppColors.light.textHint,
      );

      await pump(tester, AppTheme.darkTheme, const []);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.task_alt_rounded)).color,
        AppColors.dark.textHint,
      );
    });

    testWidgets('an approved claim tints its row with the approved token',
        (tester) async {
      // The status accent drives both the icon tint and the "waiting" label,
      // so it has to resolve per theme rather than to a fixed literal.
      for (final (theme, colors) in [
        (AppTheme.lightTheme, AppColors.light),
        (AppTheme.darkTheme, AppColors.dark),
      ]) {
        await pump(tester, theme, [item(status: 'approved')]);
        expect(tester.takeException(), isNull);

        final tinted = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(PendingItemsSection),
                matching: find.byType(Container),
              ),
            )
            .any((c) =>
                (c.decoration as BoxDecoration?)?.color ==
                colors.statusApproved.withAlpha(25));
        expect(tinted, isTrue, reason: 'expected a ${colors.statusApproved} tint');
      }
    });

    testWidgets('a submitted claim falls back to the pending token',
        (tester) async {
      await pump(tester, AppTheme.darkTheme, [item()]);

      final tinted = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(PendingItemsSection),
              matching: find.byType(Container),
            ),
          )
          .any((c) =>
              (c.decoration as BoxDecoration?)?.color ==
              AppColors.dark.statusPending.withAlpha(25));
      expect(tinted, isTrue);
    });

    testWidgets('renders in both modes without throwing', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await pump(tester, theme, [item(status: 'approved'), item()]);
        expect(tester.takeException(), isNull);
      }
    });
  });

  // ──────────────────────────────────────────────
  // Parity ledger — every substitution Phase 3B made
  // ──────────────────────────────────────────────
  group('Phase 3B substitutions resolve to the V1.0 value', () {
    test('dashboard + auth tokens map onto their legacy constants', () {
      // Each pair is `palette token` → `the AppTheme constant that call site
      // used to read`. Equality here is what makes the migration a no-op in
      // light mode.
      expect(AppColors.light.primary, AppTheme.primaryGreen);
      expect(AppColors.light.error, AppTheme.errorRed);
      expect(AppColors.light.success, AppTheme.successGreen);
      expect(AppColors.light.statusPending, AppTheme.statusPending);
      expect(AppColors.light.statusApproved, AppTheme.statusApproved);
      expect(AppColors.light.textPrimary, AppTheme.textPrimary);
      expect(AppColors.light.textSecondary, AppTheme.textSecondary);
      expect(AppColors.light.textHint, AppTheme.textHint);
      expect(AppColors.light.divider, AppTheme.dividerColor);
      expect(AppColors.light.surface, AppTheme.surfaceWhite);
    });

    test('the opaque whites that replaced Colors.white', () {
      // Page backgrounds, the auth app bars, the closed date-picker rows and
      // the Mark Paid sheet all shipped as `Colors.white`.
      expect(AppColors.light.surface.toARGB32(), Colors.white.toARGB32());
      expect(AppColors.light.surfaceElevated.toARGB32(), Colors.white.toARGB32());
      expect(AppColors.light.onPrimary.toARGB32(), Colors.white.toARGB32());
    });

    test('the notification badge label is unchanged in light mode', () {
      // The badge pins `textColor: colors.onPrimary`, replacing the inherited
      // `colorScheme.onError`. Light mode's `onError` is exactly white, so the
      // shipped badge is unchanged — and dark mode stops painting a dark-red
      // numeral on a teal badge.
      expect(AppTheme.lightTheme.colorScheme.onError, AppColors.light.onPrimary);
      expect(
        _contrast(AppColors.dark.onPrimary, AppColors.dark.primary),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
