import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/app/theme/app_colors.dart';
import 'package:rental_ledger/app/theme/app_theme.dart';
import 'package:rental_ledger/core/services/preferences_service.dart';
import 'package:rental_ledger/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WCAG contrast ratio between two colours, as `(lighter + 0.05) / (darker +
/// 0.05)`. Only meaningful for opaque colours — `computeLuminance` ignores
/// alpha, so the translucent glass tokens are excluded from contrast checks.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

/// Mirrors the theme wiring in `app.dart`: same provider, same `themeMode`
/// expression, same theme pair. `RentalLedgerApp` itself can't be pumped here
/// because it builds the app router, which needs Firebase.
class _ThemeProbe extends ConsumerWidget {
  const _ThemeProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      appSettingsProvider.select((settings) => settings.themeMode),
    );

    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: Builder(
        builder: (context) => Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              Text('brightness:${Theme.of(context).brightness.name}'),
              Text('surface:${context.colors.surface.toARGB32()}'),
              Text('primary:${context.colors.primary.toARGB32()}'),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ──────────────────────────────────────────────
  // A1 invariant — the light palette is V1.0's, value for value
  // ──────────────────────────────────────────────
  //
  // Every light value is pinned twice: against the literal that shipped, and
  // against the legacy `AppTheme` constant that existing call sites still read.
  // Either side drifting fails the suite, which is what keeps the palette safe
  // while the migration is in progress.
  group('AppColors.light preserves V1.0', () {
    test('surfaces', () {
      expect(AppColors.light.surface.toARGB32(), 0xFFFFFFFF);
      expect(AppColors.light.surface, AppTheme.surfaceWhite);

      expect(AppColors.light.surfaceElevated.toARGB32(), 0xFFFFFFFF);

      expect(AppColors.light.background.toARGB32(), 0xFFF5F5F5);
      expect(AppColors.light.background, AppTheme.backgroundLight);
    });

    test('text', () {
      expect(AppColors.light.textPrimary.toARGB32(), 0xFF1D1D1D);
      expect(AppColors.light.textPrimary, AppTheme.textPrimary);

      expect(AppColors.light.textSecondary.toARGB32(), 0xFF6B7280);
      expect(AppColors.light.textSecondary, AppTheme.textSecondary);

      expect(AppColors.light.textHint.toARGB32(), 0xFF9E9E9E);
      expect(AppColors.light.textHint, AppTheme.textHint);
    });

    test('lines', () {
      expect(AppColors.light.divider.toARGB32(), 0xFFE5E7EB);
      expect(AppColors.light.divider, AppTheme.dividerColor);

      // Only ever written inline in the light theme's input decoration.
      expect(AppColors.light.border.toARGB32(), 0xFFB0B7C3);
    });

    test('brand and semantic colours', () {
      expect(AppColors.light.primary.toARGB32(), 0xFF00897B);
      expect(AppColors.light.primary, AppTheme.primaryGreen);

      expect(AppColors.light.onPrimary.toARGB32(), 0xFFFFFFFF);

      expect(AppColors.light.error.toARGB32(), 0xFFDC3545);
      expect(AppColors.light.error, AppTheme.errorRed);

      expect(AppColors.light.success.toARGB32(), 0xFF28A745);
      expect(AppColors.light.success, AppTheme.successGreen);

      expect(AppColors.light.warning.toARGB32(), 0xFFFFC107);
      expect(AppColors.light.warning, AppTheme.warningOrange);
    });

    test('expense status colours', () {
      expect(AppColors.light.statusPending, AppTheme.statusPending);
      expect(AppColors.light.statusApproved, AppTheme.statusApproved);
      expect(AppColors.light.statusPaid, AppTheme.statusPaid);
      expect(AppColors.light.statusRejected, AppTheme.statusRejected);
      expect(
        AppColors.light.statusDirectPayment,
        AppTheme.statusDirectPayment,
      );

      // StatusBadge's fallback for an unrecognised status. This one is
      // *identical* to `Colors.grey`, not merely value-equal to a fresh
      // `Color(0xFF9E9E9E)`: the shipped badge returned the swatch itself and
      // `status_badge_test` asserts against it. Compared by value because
      // `Colors.grey` is a `ColorSwatch`, which implements `Map`, so `expect`
      // would otherwise deep-compare it as a map rather than as a colour.
      expect(AppColors.light.statusNeutral.toARGB32(), 0xFF9E9E9E);
      expect(AppColors.light.statusNeutral.toARGB32(), Colors.grey.toARGB32());
      expect(identical(AppColors.light.statusNeutral, Colors.grey), isTrue);
    });

    test('category fallback', () {
      expect(AppColors.light.categoryFallback.toARGB32(), 0xFF95A5A6);
      expect(
        AppColors.light.categoryFallback.toARGB32(),
        AppTheme.categoryFallbackHex,
      );
    });

    test('skeleton placeholders', () {
      // SkeletonBox's default fill and Shimmer's highlight.
      expect(AppColors.light.skeletonBase.toARGB32(), 0xFFEDEFF2);
      expect(AppColors.light.skeletonHighlight.toARGB32(), 0xFFFAFBFC);
    });

    test('glass', () {
      // Colors.white.withAlpha(191) — GlassCard's default fill at opacity 0.75.
      expect(AppColors.light.glassFill.toARGB32(), 0xBFFFFFFF);
      // Colors.white.withAlpha(120) — GlassCard's border.
      expect(AppColors.light.glassBorder.toARGB32(), 0x78FFFFFF);
      // Colors.black.withAlpha(10) — GlassCard's shadow.
      expect(AppColors.light.glassShadow.toARGB32(), 0x0A000000);
      // The app bar's and bottom nav's frosted chrome.
      expect(AppColors.light.glassBarFill.toARGB32(), 0xF7FFFFFF);
      // Colors.black.withAlpha(13) — the card theme's shadow.
      expect(AppColors.light.shadow.toARGB32(), 0x0D000000);
    });
  });

  // ──────────────────────────────────────────────
  // Dark palette
  // ──────────────────────────────────────────────
  group('AppColors.dark', () {
    test('is a deep neutral ramp, not pure black', () {
      for (final color in [
        AppColors.dark.background,
        AppColors.dark.surface,
        AppColors.dark.surfaceElevated,
      ]) {
        expect(
          color.computeLuminance(),
          greaterThan(0.0),
          reason: 'pure black is harsh on OLED and flattens the surface ramp',
        );
      }
    });

    test('ramps upward: background < surface < surfaceElevated', () {
      expect(
        AppColors.dark.background.computeLuminance(),
        lessThan(AppColors.dark.surface.computeLuminance()),
      );
      expect(
        AppColors.dark.surface.computeLuminance(),
        lessThan(AppColors.dark.surfaceElevated.computeLuminance()),
      );
    });

    test('primary is a lighter teal than the light theme', () {
      expect(
        AppColors.dark.primary.computeLuminance(),
        greaterThan(AppColors.light.primary.computeLuminance()),
      );
    });

    test('onPrimary is dark ink, and clears AA against primary (Q1b)', () {
      expect(
        AppColors.dark.onPrimary.computeLuminance(),
        lessThan(AppColors.dark.primary.computeLuminance()),
        reason: 'the dark primary is lightened, so it takes a dark foreground',
      );
      expect(
        _contrast(AppColors.dark.onPrimary, AppColors.dark.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('text clears WCAG AA on the surface', () {
      final surface = AppColors.dark.surface;

      expect(
        _contrast(AppColors.dark.textPrimary, surface),
        greaterThanOrEqualTo(7.0),
      );
      expect(
        _contrast(AppColors.dark.textSecondary, surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.dark.textHint, surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('accents and status colours clear AA on the surface', () {
      final surface = AppColors.dark.surface;

      final accents = <String, Color>{
        'primary': AppColors.dark.primary,
        'error': AppColors.dark.error,
        'success': AppColors.dark.success,
        'warning': AppColors.dark.warning,
        'statusPending': AppColors.dark.statusPending,
        'statusApproved': AppColors.dark.statusApproved,
        'statusPaid': AppColors.dark.statusPaid,
        'statusRejected': AppColors.dark.statusRejected,
        'statusDirectPayment': AppColors.dark.statusDirectPayment,
        'statusNeutral': AppColors.dark.statusNeutral,
        'categoryFallback': AppColors.dark.categoryFallback,
      };

      accents.forEach((name, color) {
        expect(
          _contrast(color, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$name must stay legible on the dark surface',
        );
      });
    });

    test('every status colour is distinct from the others', () {
      final statuses = [
        AppColors.dark.statusPending,
        AppColors.dark.statusApproved,
        AppColors.dark.statusPaid,
        AppColors.dark.statusRejected,
        AppColors.dark.statusDirectPayment,
      ];

      expect(statuses.toSet().length, statuses.length);
    });

    test('glass stays subtle rather than filling with white', () {
      expect(
        AppColors.dark.glassFill.a,
        lessThan(AppColors.light.glassFill.a),
        reason: 'a 75%-white card would blow out a dark surface',
      );
      expect(AppColors.dark.glassBorder.a, lessThan(0.3));
    });

    test('the chrome bar is near-opaque, not see-through', () {
      expect(AppColors.dark.glassBarFill.a, greaterThanOrEqualTo(0.9));
    });
  });

  // ──────────────────────────────────────────────
  // ThemeExtension plumbing
  // ──────────────────────────────────────────────
  group('ThemeExtension registration', () {
    test('lightTheme registers AppColors.light', () {
      expect(AppTheme.lightTheme.extension<AppColors>(), AppColors.light);
    });

    test('darkTheme registers AppColors.dark', () {
      expect(AppTheme.darkTheme.extension<AppColors>(), AppColors.dark);
    });

    test('the two palettes are distinct', () {
      expect(AppColors.light, isNot(AppColors.dark));
    });

    test('a theme with no registration falls back to the light palette', () {
      final bare = ThemeData(useMaterial3: true);

      expect(bare.extension<AppColors>(), isNull);
    });

    test('copyWith replaces only the named tokens', () {
      final recoloured = AppColors.light.copyWith(primary: Colors.pink);

      expect(recoloured.primary, Colors.pink);
      expect(recoloured.surface, AppColors.light.surface);
      expect(recoloured.textPrimary, AppColors.light.textPrimary);
    });

    test('value equality holds for identical palettes', () {
      expect(AppColors.light, AppColors.light.copyWith());
      expect(AppColors.light.hashCode, AppColors.light.copyWith().hashCode);
      expect(AppColors.light == AppColors.dark, isFalse);
    });

    test('lerp halfway lands between the two palettes', () {
      final mid = AppColors.light.lerp(AppColors.dark, 0.5);

      expect(
        mid.surface.computeLuminance(),
        lessThan(AppColors.light.surface.computeLuminance()),
      );
      expect(
        mid.surface.computeLuminance(),
        greaterThan(AppColors.dark.surface.computeLuminance()),
      );
    });

    test('lerp endpoints reproduce each palette', () {
      expect(AppColors.light.lerp(AppColors.dark, 0.0), AppColors.light);
      expect(AppColors.light.lerp(AppColors.dark, 1.0), AppColors.dark);
    });
  });

  // ──────────────────────────────────────────────
  // Theme data validity
  // ──────────────────────────────────────────────
  group('AppTheme.lightTheme', () {
    test('remains a valid light theme', () {
      final theme = AppTheme.lightTheme;

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppTheme.backgroundLight);
    });

    test('its palette does not touch the dark one', () {
      final colors = AppTheme.lightTheme.extension<AppColors>()!;

      expect(colors.surface, AppTheme.surfaceWhite);
      expect(colors.background, AppTheme.backgroundLight);
      expect(colors.surface, isNot(AppColors.dark.surface));
    });
  });

  group('AppTheme.darkTheme', () {
    test('is a valid dark theme', () {
      final theme = AppTheme.darkTheme;

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.dark.background);
    });

    test('the colour scheme follows the palette', () {
      final scheme = AppTheme.darkTheme.colorScheme;

      expect(scheme.primary, AppColors.dark.primary);
      expect(scheme.onPrimary, AppColors.dark.onPrimary);
      expect(scheme.surface, AppColors.dark.surface);
      expect(scheme.error, AppColors.dark.error);
    });

    test('shares the light theme geometry — only colour differs', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      // Shapes and spacing must match, or switching appearance would shift
      // layout rather than only recolour it.
      expect(dark.cardTheme.shape, light.cardTheme.shape);
      expect(dark.cardTheme.margin, light.cardTheme.margin);
      expect(dark.cardTheme.elevation, light.cardTheme.elevation);

      expect(dark.appBarTheme.centerTitle, light.appBarTheme.centerTitle);
      expect(dark.appBarTheme.elevation, light.appBarTheme.elevation);
      expect(
        dark.appBarTheme.scrolledUnderElevation,
        light.appBarTheme.scrolledUnderElevation,
      );
      expect(
        dark.appBarTheme.titleTextStyle?.fontSize,
        light.appBarTheme.titleTextStyle?.fontSize,
      );

      expect(dark.bottomSheetTheme.shape, light.bottomSheetTheme.shape);
      expect(dark.chipTheme.shape, light.chipTheme.shape);
      expect(dark.chipTheme.padding, light.chipTheme.padding);
      expect(dark.chipTheme.showCheckmark, light.chipTheme.showCheckmark);

      expect(
        dark.dividerTheme.thickness,
        light.dividerTheme.thickness,
      );
      expect(dark.dividerTheme.space, light.dividerTheme.space);

      expect(
        dark.inputDecorationTheme.contentPadding,
        light.inputDecorationTheme.contentPadding,
      );
      expect(
        (dark.inputDecorationTheme.enabledBorder! as OutlineInputBorder)
            .borderRadius,
        (light.inputDecorationTheme.enabledBorder! as OutlineInputBorder)
            .borderRadius,
      );

      expect(
        dark.bottomNavigationBarTheme.type,
        light.bottomNavigationBarTheme.type,
      );
      expect(dark.snackBarTheme.behavior, light.snackBarTheme.behavior);
      expect(dark.snackBarTheme.shape, light.snackBarTheme.shape);
    });

    test('chip and FAB foregrounds follow the palette, not white', () {
      expect(
        AppTheme.darkTheme.chipTheme.secondaryLabelStyle?.color,
        AppColors.dark.onPrimary,
      );
      expect(
        AppTheme.darkTheme.floatingActionButtonTheme.foregroundColor,
        AppColors.dark.onPrimary,
      );
      expect(
        AppTheme.darkTheme.floatingActionButtonTheme.backgroundColor,
        AppColors.dark.primary,
      );
    });
  });

  // ──────────────────────────────────────────────
  // themeMode wiring
  // ──────────────────────────────────────────────
  group('themeMode wiring', () {
    /// Pumps [_ThemeProbe] over a store seeded with [storedMode].
    Future<ProviderContainer> pump(
      WidgetTester tester, {
      ThemeMode? storedMode,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        if (storedMode != null)
          'settings.themeMode': storedMode.name,
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const _ThemeProbe(),
        ),
      );

      return ProviderScope.containerOf(tester.element(find.byType(_ThemeProbe)));
    }

    testWidgets('defaults to system, following a light platform',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pump(tester);

      expect(find.text('brightness:light'), findsOneWidget);
      expect(find.text('surface:${AppColors.light.surface.toARGB32()}'),
          findsOneWidget);
    });

    testWidgets('system follows a dark platform', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pump(tester);

      expect(find.text('brightness:dark'), findsOneWidget);
      expect(find.text('primary:${AppColors.dark.primary.toARGB32()}'),
          findsOneWidget);
    });

    testWidgets('an explicit light choice overrides a dark platform',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pump(tester, storedMode: ThemeMode.light);

      expect(find.text('brightness:light'), findsOneWidget);
      expect(find.text('surface:${AppColors.light.surface.toARGB32()}'),
          findsOneWidget);
    });

    testWidgets('an explicit dark choice overrides a light platform',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await pump(tester, storedMode: ThemeMode.dark);

      expect(find.text('brightness:dark'), findsOneWidget);
      expect(find.text('surface:${AppColors.dark.surface.toARGB32()}'),
          findsOneWidget);
    });

    testWidgets('switching the setting at runtime repaints the theme',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final container = await pump(tester);
      expect(find.text('brightness:light'), findsOneWidget);

      container.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      expect(find.text('brightness:dark'), findsOneWidget);
      expect(find.text('surface:${AppColors.dark.surface.toARGB32()}'),
          findsOneWidget);

      container
          .read(appSettingsProvider.notifier)
          .setThemeMode(ThemeMode.system);
      await tester.pumpAndSettle();

      expect(find.text('brightness:light'), findsOneWidget);
    });

    testWidgets('a runtime choice is persisted for the next launch',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final container = await pump(tester);
      container.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('settings.themeMode'),
        ThemeMode.dark.name,
      );
    });
  });
}
