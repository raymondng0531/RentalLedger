import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/services/firebase_service.dart';
import 'core/services/isar_service.dart';
import 'core/services/preferences_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/utils/currency_utils.dart';

Future<void> main() async {
  // ── Ensure Flutter bindings are ready ──
  WidgetsFlutterBinding.ensureInitialized();

  // ── Global error handler to catch unhandled exceptions ──
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[App] Unhandled error: ${details.exception}');
    debugPrint('[App] Stack: ${details.stack}');
  };

  // ── Set preferred orientations ──
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── System UI overlay style ──
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ── Initialize Firebase ──
  FirebaseInitResult firebaseResult;
  try {
    await FirebaseService.instance.initialize();
    firebaseResult = FirebaseInitResult.success;
    debugPrint('[main] Firebase initialized successfully.');
  } catch (e) {
    debugPrint('[main] Firebase init failed: $e');
    firebaseResult = const FirebaseInitResult(
      false,
      'Firebase is not configured.\n\n'
      'Run `flutterfire configure` or add google-services.json\n'
      'to run the app with full functionality.',
    );
  }

  // Isar is optional — failure is non-fatal.
  await IsarService.instance.initialize();

  // ── Local preferences ──
  // Loaded before runApp so a persisted appearance choice is already applied on
  // the first frame; loading it later would flash the default theme on every
  // launch. Non-fatal: with no store the app runs on defaults (see
  // PreferencesService).
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('[main] Local preference storage unavailable: $e');
  }

  // ── Seed the currency symbol ──
  // `CurrencyUtils` holds the symbol as process-global state, so hydrating
  // `AppSettings.currency` is not enough on its own: every amount formats from
  // this static, and it would otherwise sit at its MYR default until the user
  // opened the picker. Applied before runApp — the same reason the theme and
  // language are read before runApp — so the first frame already shows the
  // persisted currency rather than flashing RM.
  CurrencyUtils.setCurrencyCode(PreferencesService(preferences).readCurrency());

  // Set up push notifications (only if Firebase is configured).
  if (firebaseResult.isSuccess) {
    await PushNotificationService.instance.initialize();
  }

  // ── Launch app ──
  runApp(
    ProviderScope(
      overrides: [
        firebaseInitResultProvider.overrideWithValue(firebaseResult),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const RentalLedgerApp(),
    ),
  );
}
