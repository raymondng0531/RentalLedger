import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/services/preferences_service.dart';
import 'package:rental_ledger/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the store back through a *fresh* service, which is what a page reload
/// actually does — the service itself holds no state, so anything it returns
/// must have come from the store.
PreferencesService _reopen(SharedPreferences prefs) =>
    PreferencesService(prefs);

/// Lets the fire-and-forget persistence write in `setThemeMode` settle.
Future<void> _flushWrites() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Fresh in-memory store per test — no cross-test bleed.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('PreferencesService.readThemeMode', () {
    test('defaults to system when nothing is stored', () async {
      final prefs = await SharedPreferences.getInstance();

      expect(_reopen(prefs).readThemeMode(), ThemeMode.system);
    });

    test('defaults to system when no store is available', () {
      const service = PreferencesService(null);

      expect(service.readThemeMode(), ThemeMode.system);
      expect(service.isAvailable, isFalse);
    });

    test('falls back to system for an unrecognised stored value', () async {
      // e.g. written by a newer build that added a mode this one doesn't know.
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.themeModeKey: 'sepia',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(_reopen(prefs).readThemeMode(), ThemeMode.system);
    });
  });

  group('PreferencesService persistence', () {
    for (final mode in ThemeMode.values) {
      test('${mode.name} survives a round trip', () async {
        final prefs = await SharedPreferences.getInstance();
        await _reopen(prefs).writeThemeMode(mode);

        // The raw store holds the value...
        expect(
          prefs.getString(PreferencesService.themeModeKey),
          mode.name,
          reason: 'value must actually reach the store, not just memory',
        );
        // ...and a reopened service reads it back.
        expect(_reopen(prefs).readThemeMode(), mode);
      });
    }

    test('writing over an existing value replaces it', () async {
      final prefs = await SharedPreferences.getInstance();
      await _reopen(prefs).writeThemeMode(ThemeMode.dark);
      await _reopen(prefs).writeThemeMode(ThemeMode.light);

      expect(_reopen(prefs).readThemeMode(), ThemeMode.light);
    });

    test('writes are silently dropped without a store', () async {
      const service = PreferencesService(null);

      await expectLater(service.writeThemeMode(ThemeMode.dark), completes);
    });
  });

  group('AppSettings', () {
    test('defaults to system appearance', () {
      const settings = AppSettings();

      expect(settings.themeMode, ThemeMode.system);
    });

    test('darkMode is derived: true only for an explicit dark choice', () {
      const settings = AppSettings();

      expect(settings.darkMode, isFalse);
      expect(
        settings.copyWith(themeMode: ThemeMode.system).darkMode,
        isFalse,
        reason: 'system is not "dark mode on" — it depends on the device',
      );
      expect(
        settings.copyWith(themeMode: ThemeMode.light).darkMode,
        isFalse,
      );
      expect(settings.copyWith(themeMode: ThemeMode.dark).darkMode, isTrue);
    });

    test('copyWith carries themeMode through', () {
      const settings = AppSettings(themeMode: ThemeMode.dark);

      expect(settings.copyWith(language: 'en').themeMode, ThemeMode.dark);
      expect(
        settings.copyWith(themeMode: ThemeMode.light).themeMode,
        ThemeMode.light,
      );
    });
  });

  group('AppSettingsNotifier', () {
    test('hydrates the persisted appearance on construction', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.themeModeKey: ThemeMode.dark.name,
      });
      final prefs = await SharedPreferences.getInstance();

      final notifier = AppSettingsNotifier(_reopen(prefs));

      expect(notifier.state.themeMode, ThemeMode.dark);
    });

    test('hydrates to system with no stored preference', () async {
      final prefs = await SharedPreferences.getInstance();

      final notifier = AppSettingsNotifier(_reopen(prefs));

      expect(notifier.state.themeMode, ThemeMode.system);
    });

    test('setThemeMode updates state and persists', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppSettingsNotifier(_reopen(prefs));

      notifier.setThemeMode(ThemeMode.dark);
      expect(notifier.state.themeMode, ThemeMode.dark);

      await _flushWrites();
      expect(
        prefs.getString(PreferencesService.themeModeKey),
        ThemeMode.dark.name,
      );
    });

    test('setThemeMode persists an explicit system choice', () async {
      // Regression guard: "system" must be written, not treated as "unset" —
      // otherwise switching back from dark would not stick across a refresh.
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.themeModeKey: ThemeMode.dark.name,
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppSettingsNotifier(_reopen(prefs));

      notifier.setThemeMode(ThemeMode.system);
      await _flushWrites();

      expect(
        prefs.getString(PreferencesService.themeModeKey),
        ThemeMode.system.name,
      );
      expect(_reopen(prefs).readThemeMode(), ThemeMode.system);
    });

    test('setThemeMode is a no-op when the mode is unchanged', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppSettingsNotifier(_reopen(prefs));
      final before = notifier.state;

      notifier.setThemeMode(ThemeMode.system);

      expect(identical(notifier.state, before), isTrue);
    });

    test('setDarkMode shim maps onto an explicit light/dark choice', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppSettingsNotifier(_reopen(prefs));

      notifier.setDarkMode(true);
      expect(notifier.state.themeMode, ThemeMode.dark);

      notifier.setDarkMode(false);
      expect(
        notifier.state.themeMode,
        ThemeMode.light,
        reason: 'legacy false means Light, not "follow the system"',
      );

      await _flushWrites();
      expect(
        prefs.getString(PreferencesService.themeModeKey),
        ThemeMode.light.name,
      );
    });

    test('unrelated settings still work alongside themeMode', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppSettingsNotifier(_reopen(prefs));

      notifier.setLanguage('en');
      notifier.setNotificationsEnabled(false);
      notifier.setThemeMode(ThemeMode.dark);

      expect(notifier.state.language, 'en');
      expect(notifier.state.notificationsEnabled, isFalse);
      expect(notifier.state.themeMode, ThemeMode.dark);
    });
  });

  group('appSettingsProvider', () {
    /// Builds the provider graph the way `main()` does, over a mock store.
    ProviderContainer containerOver(SharedPreferences? prefs) {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('reads the persisted appearance from the overridden store', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.themeModeKey: ThemeMode.dark.name,
      });
      final prefs = await SharedPreferences.getInstance();

      final container = containerOver(prefs);

      expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
    });

    test('defaults to system when no store was provided', () {
      final container = containerOver(null);

      expect(container.read(appSettingsProvider).themeMode, ThemeMode.system);
    });

    test('selecting a mode persists it for the next launch', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = containerOver(prefs);

      container.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.dark);
      await _flushWrites();

      // Simulate the next launch: same store, brand new provider graph.
      final relaunched = containerOver(prefs);
      expect(relaunched.read(appSettingsProvider).themeMode, ThemeMode.dark);
    });
  });
}
