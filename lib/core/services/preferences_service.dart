import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local, device-scoped user preferences.
///
/// Backed by `shared_preferences` — on Web that is browser `localStorage`, so a
/// preference survives a page refresh or restart with no network round-trip.
/// Deliberately local-only: no Firestore, no security rules, no backend.
///
/// The backing store is **nullable on purpose**. `SharedPreferences.getInstance()`
/// can fail on Web when site data is blocked (private browsing, blocked cookies),
/// and local storage is not important enough to abort startup over — the same
/// non-fatal treatment [IsarService] gets. With no store, reads fall back to the
/// defaults and writes are silently dropped.
class PreferencesService {
  const PreferencesService(this._prefs);

  final SharedPreferences? _prefs;

  /// Storage key for the persisted appearance setting.
  ///
  /// Namespaced so future preference keys can share the same store without
  /// colliding with anything else the app writes there.
  static const String themeModeKey = 'settings.themeMode';

  /// Storage key for the persisted language setting.
  static const String languageKey = 'settings.language';

  /// The language used when nothing is stored yet, and whenever a stored value
  /// is unrecognised.
  ///
  /// English is the app's baseline UI language, so it is the safe default: a
  /// missing or corrupt value can only ever fall back to text that is already
  /// known to be complete.
  static const String defaultLanguage = 'en';

  /// Language codes the app ships translations for.
  ///
  /// Kept here as plain codes (not [Locale]s) to match what is stored on disk —
  /// a `SharedPreferences` string. This list is the validation boundary: the
  /// only place an unknown language can enter the app.
  static const List<String> supportedLanguages = <String>['en', 'ms'];

  /// Storage key for the persisted currency setting.
  static const String currencyKey = 'settings.currency';

  /// The currency used when nothing is stored yet, and whenever a stored value
  /// is unrecognised.
  ///
  /// MYR is the app's original and only hardcoded currency, so it is the safe
  /// default: a missing or corrupt value can only ever fall back to what the
  /// app already shipped.
  static const String defaultCurrency = 'MYR';

  /// Currency codes the app can display a symbol for.
  ///
  /// This list is the validation boundary — the only place an unknown currency
  /// can enter the app — and it mirrors the codes `CurrencyUtils` knows. Kept
  /// here as plain codes to match what is stored on disk.
  static const List<String> supportedCurrencies = <String>[
    'MYR',
    'SGD',
    'USD',
  ];

  /// Whether a backing store is actually available.
  ///
  /// Exposed for tests and diagnostics; the app never needs to branch on it.
  bool get isAvailable => _prefs != null;

  /// Reads the persisted appearance mode.
  ///
  /// Returns [ThemeMode.system] when nothing is stored yet — the intended
  /// default, so a first-time user follows their device/browser theme — and
  /// also when the stored value is unrecognised (e.g. written by a newer build
  /// that added a mode this one doesn't know).
  ThemeMode readThemeMode() {
    final stored = _prefs?.getString(themeModeKey);
    if (stored == null) return ThemeMode.system;

    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  /// Persists the selected appearance [mode].
  ///
  /// The enum's `name` is stored rather than its `index`, so the value stays
  /// readable in devtools and survives any future reordering of the enum.
  Future<void> writeThemeMode(ThemeMode mode) async {
    await _prefs?.setString(themeModeKey, mode.name);
  }

  /// Reads the persisted language code.
  ///
  /// Returns [defaultLanguage] when nothing is stored yet and also when the
  /// stored value is unrecognised — the same two-case fallback [readThemeMode]
  /// uses, so a value written by a future build can never put the app into a
  /// locale it has no translations for.
  String readLanguage() {
    final stored = _prefs?.getString(languageKey);
    if (stored == null) return defaultLanguage;

    return supportedLanguages.contains(stored) ? stored : defaultLanguage;
  }

  /// Persists the selected language code.
  ///
  /// Stored as the plain code (`'en'` / `'ms'`) so the value stays readable in
  /// devtools and maps directly onto [Locale].
  Future<void> writeLanguage(String language) async {
    await _prefs?.setString(languageKey, language);
  }

  /// Reads the persisted currency code.
  ///
  /// Returns [defaultCurrency] when nothing is stored yet and also when the
  /// stored value is unrecognised — the same two-case fallback [readLanguage]
  /// uses, so a value written by a future build can never put the app into a
  /// currency it has no symbol for.
  String readCurrency() {
    final stored = _prefs?.getString(currencyKey);
    if (stored == null) return defaultCurrency;

    return supportedCurrencies.contains(stored) ? stored : defaultCurrency;
  }

  /// Persists the selected currency code.
  Future<void> writeCurrency(String currency) async {
    await _prefs?.setString(currencyKey, currency);
  }
}

// ───── Providers ─────

/// The loaded `SharedPreferences` instance, or `null` when local storage is
/// unavailable.
///
/// Overridden in `main()` with the instance loaded *before* `runApp`, following
/// the same [firebaseInitResultProvider] pattern. Resolving it up front is what
/// lets the first frame render with the persisted theme already applied, so a
/// dark-mode user never sees a light flash on launch.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Preferences service over the loaded store.
final preferencesServiceProvider = Provider<PreferencesService>(
  (ref) => PreferencesService(ref.watch(sharedPreferencesProvider)),
);
