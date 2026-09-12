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
