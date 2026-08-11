import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'router/app_router.dart';

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

    return MaterialApp.router(
      title: 'Rental Ledger',
      debugShowCheckedModeBanner: false,

      // ── Theme ──
      theme: AppTheme.lightTheme,
      // Dark mode is a future enhancement — no darkTheme set.
      themeMode: ThemeMode.light,

      // ── Router ──
      routerConfig: router,

      // ── Localization ──
      locale: const Locale('ms', 'MY'),
    );
  }
}
