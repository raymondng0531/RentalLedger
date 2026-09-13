import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'router/app_router.dart';
import '../features/settings/presentation/providers/settings_provider.dart';
import '../l10n/generated/app_localizations.dart';

/// Root widget for Rental Ledger.
///
/// Sets up the Riverpod ProviderScope, Material Design 3 theme,
/// and GoRouter navigation (powered by [goRouterProvider] which
/// watches auth state for automatic redirects).
class RentalLedgerApp extends ConsumerWidget {
  const RentalLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    // The appearance setting lives with the rest of the app's settings rather
    // than in a theme-specific provider — one source of truth, hydrated from
    // local storage before `runApp` so the first frame is already correct.
    final themeMode = ref.watch(
      appSettingsProvider.select((settings) => settings.themeMode),
    );
    // Same single source of truth for language: `AppSettings.language` is
    // hydrated from local storage before `runApp`, so the first frame already
    // carries the persisted choice.
    final language = ref.watch(
      appSettingsProvider.select((settings) => settings.language),
    );

    return MaterialApp.router(
      title: 'Rental Ledger',
      debugShowCheckedModeBanner: false,

      // ── Theme ──
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // System follows the device/browser preference; light and dark are
      // explicit overrides.
      themeMode: themeMode,

      // ── Router ──
      routerConfig: router,

      // ── Localization ──
      // The selected language, not a fixed constant. `supportedLocales` is
      // generated from the ARB files, so it is exactly [en, ms]; an
      // unrecognised stored value falls back to the first entry (English) via
      // Flutter's standard locale resolution, and `PreferencesService` already
      // normalises anything unknown to 'en' on read.
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
