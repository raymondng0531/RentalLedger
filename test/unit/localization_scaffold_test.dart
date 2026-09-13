import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:rental_ledger/core/services/preferences_service.dart';
import 'package:rental_ledger/features/settings/presentation/providers/settings_provider.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scaffold-level proof that the localization *infrastructure* works.
///
/// Phase 1 wires generation, the delegate, the supported locales and local
/// persistence — but deliberately leaves every existing UI string hardcoded, so
/// there is nothing in the widget tree to assert against yet. These tests
/// therefore exercise the generated [AppLocalizations] and the settings plumbing
/// directly, which is exactly the layer Phase 2+ will build on.
///
/// Nothing here asserts the *content* of the app's real translations; that
/// belongs to the per-screen migration.

/// Reads the store back through a *fresh* service, which is what a page reload
/// actually does — the service holds no state, so anything it returns must have
/// come from the store.
PreferencesService _reopen(SharedPreferences prefs) => PreferencesService(prefs);

/// Lets the fire-and-forget persistence write in `setLanguage` settle.
Future<void> _flushWrites() => Future<void>.delayed(Duration.zero);

/// The smallest tree that exercises the generated delegate: a `MaterialApp`
/// carrying the real delegates and supported locales from the ARB files, with a
/// child that reads a translated string.
Widget _harness(Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) =>
            Text(AppLocalizations.of(context).languageSectionTitle),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Fresh in-memory store per test — no cross-test bleed.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('generated AppLocalizations', () {
    test('supports exactly English and Bahasa Melayu', () {
      expect(
        AppLocalizations.supportedLocales,
        <Locale>[const Locale('en'), const Locale('ms')],
        reason: 'the shipped language set is a product decision, not an '
            'incidental side effect of which ARB files happen to exist',
      );
    });

    test('exposes the standard delegates, including the global three', () {
      expect(
        AppLocalizations.localizationsDelegates,
        containsAll(<LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ]),
      );
    });

    test('resolves English for an English locale', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));

      expect(en.languageSectionTitle, 'Language');
      expect(en.scaffoldGreeting('Raymond'), 'Hello, Raymond');
    });

    test('resolves Malay for a Malay locale', () async {
      final ms = await AppLocalizations.delegate.load(const Locale('ms'));

      expect(ms.languageSectionTitle, 'Bahasa');
      expect(ms.scaffoldGreeting('Raymond'), 'Helo, Raymond');
    });

    test('applies ICU plurals per locale', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final ms = await AppLocalizations.delegate.load(const Locale('ms'));

      expect(en.scaffoldItemCount(0), 'No items');
      expect(en.scaffoldItemCount(1), '1 item');
      expect(en.scaffoldItemCount(5), '5 items');

      // Malay does not inflect for number, so every count uses the same noun.
      expect(ms.scaffoldItemCount(5), '5 item');
    });
  });

  group('AppSettings.language', () {
    test('defaults to English', () {
      expect(const AppSettings().language, 'en');
      expect(PreferencesService.defaultLanguage, 'en');
    });

    test('copyWith carries language through', () {
      const settings = AppSettings(language: 'ms');

      expect(settings.copyWith(themeMode: ThemeMode.dark).language, 'ms');
      expect(settings.copyWith(language: 'en').language, 'en');
    });
  });

  group('PreferencesService language persistence', () {
    test('defaults to English when nothing is stored', () async {
      final prefs = await SharedPreferences.getInstance();

      expect(_reopen(prefs).readLanguage(), 'en');
    });

    test('defaults to English when no store is available', () {
      const service = PreferencesService(null);

      expect(service.readLanguage(), 'en');
      expect(service.isAvailable, isFalse);
    });

    test('falls back to English for an unrecognised stored value', () async {
      // e.g. a language added by a newer build, or a hand-edited localStorage.
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.languageKey: 'ta',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(_reopen(prefs).readLanguage(), 'en');
    });

    for (final language in PreferencesService.supportedLanguages) {
      test('$language survives a round trip', () async {
        final prefs = await SharedPreferences.getInstance();
        await _reopen(prefs).writeLanguage(language);

        // The raw store holds the value...
        expect(
          prefs.getString(PreferencesService.languageKey),
          language,
          reason: 'value must actually reach the store, not just memory',
        );
        // ...and a reopened service reads it back.
        expect(_reopen(prefs).readLanguage(), language);
      });
    }

    test('writes are silently dropped without a store', () async {
      const service = PreferencesService(null);

      await expectLater(service.writeLanguage('ms'), completes);
    });

    test('language and appearance share one store, not two', () async {
      final prefs = await SharedPreferences.getInstance();
      await _reopen(prefs).writeLanguage('ms');
      await _reopen(prefs).writeThemeMode(ThemeMode.dark);

      // Both preferences are reachable from the same instance — the existing
      // local-only architecture, extended rather than duplicated.
      expect(_reopen(prefs).readLanguage(), 'ms');
      expect(_reopen(prefs).readThemeMode(), ThemeMode.dark);
    });
  });

  group('AppSettingsNotifier language', () {
    test('hydrates the persisted language on construction', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.languageKey: 'ms',
      });
      final prefs = await SharedPreferences.getInstance();

      final notifier = AppSettingsNotifier(_reopen(prefs));

      expect(notifier.state.language, 'ms');
    });

    test('hydrates to English with no stored preference', () async {
      final prefs = await SharedPreferences.getInstance();

      final notifier = AppSettingsNotifier(_reopen(prefs));

      expect(notifier.state.language, 'en');
    });

    test('setLanguage updates state and persists', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppSettingsNotifier(_reopen(prefs));

      notifier.setLanguage('ms');
      expect(notifier.state.language, 'ms');

      await _flushWrites();
      expect(prefs.getString(PreferencesService.languageKey), 'ms');
    });

    test('setLanguage is a no-op when the language is unchanged', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppSettingsNotifier(_reopen(prefs));
      final before = notifier.state;

      notifier.setLanguage('en');

      expect(identical(notifier.state, before), isTrue);
    });

    test('the choice survives a simulated relaunch', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppSettingsNotifier(_reopen(prefs));
      notifier.setLanguage('ms');
      await _flushWrites();

      // Same store, brand new notifier — what the next launch actually does.
      expect(AppSettingsNotifier(_reopen(prefs)).state.language, 'ms');
    });
  });

  group('language drives the localization lookup', () {
    /// The app's real wiring in miniature: the locale comes from
    /// `AppSettings.language`, exactly as `MaterialApp.router` does it.
    Widget appHarness(SharedPreferences prefs) => ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: Consumer(
            builder: (context, ref, _) {
              final language = ref.watch(
                appSettingsProvider.select((settings) => settings.language),
              );
              return MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Builder(
                  builder: (context) =>
                      Text(AppLocalizations.of(context).languageSectionTitle),
                ),
              );
            },
          ),
        );

    testWidgets('renders English by default', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(appHarness(prefs));

      expect(find.text('Language'), findsOneWidget);
    });

    testWidgets('renders the persisted language on first frame',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.languageKey: 'ms',
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(appHarness(prefs));

      expect(
        find.text('Bahasa'),
        findsOneWidget,
        reason: 'hydration happens before runApp, so there must be no flash of '
            'English on launch',
      );
      expect(find.text('Language'), findsNothing);
    });

    testWidgets('switching language changes the localized text',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(appHarness(prefs));
      expect(find.text('Language'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(appSettingsProvider.notifier).setLanguage('ms');
      await tester.pumpAndSettle();

      expect(find.text('Bahasa'), findsOneWidget);
      expect(find.text('Language'), findsNothing);

      // ...and back again.
      container.read(appSettingsProvider.notifier).setLanguage('en');
      await tester.pumpAndSettle();

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Bahasa'), findsNothing);
    });

    testWidgets('an unsupported locale resolves to English', (tester) async {
      await tester.pumpWidget(_harness(const Locale('ta')));

      expect(find.text('Language'), findsOneWidget);
    });
  });

  group('intl date symbols', () {
    testWidgets('are registered for Malay by the Material delegate',
        (tester) async {
      // No `initializeDateFormatting` call anywhere in the app: loading the
      // Material delegate is what registers intl's date symbols, for every
      // locale Flutter ships — not just the requested one. This pins that
      // behaviour so `main()` never needs manual intl setup.
      await tester.pumpWidget(_harness(const Locale('ms')));

      expect(intl.DateFormat('MMMM', 'ms').format(DateTime(2026, 1, 15)),
          'Januari');
      expect(intl.DateFormat('MMMM', 'en').format(DateTime(2026, 1, 15)),
          'January');
    });
  });
}
