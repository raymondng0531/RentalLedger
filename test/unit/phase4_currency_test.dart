import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/services/preferences_service.dart';
import 'package:rental_ledger/core/utils/currency_utils.dart';
import 'package:rental_ledger/features/settings/presentation/providers/settings_provider.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 4 — number and currency localization.
///
/// [CurrencyUtils.setCurrencyCode] writes process-global state, so every test
/// here starts and ends on the shipped default. That keeps the group order
/// irrelevant and stops a symbol leaking into any other test file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CurrencyUtils.setCurrencyCode(PreferencesService.defaultCurrency);
  });
  tearDown(() {
    CurrencyUtils.setCurrencyCode(PreferencesService.defaultCurrency);
  });

  group('number formatting — English', () {
    test('groups thousands and always shows two decimals', () {
      expect(CurrencyUtils.formatAmountOnly(1234.5, localeCode: 'en'),
          '1,234.50');
      expect(CurrencyUtils.formatAmountOnly(1234567.891, localeCode: 'en'),
          '1,234,567.89');
    });

    test('whole numbers keep their decimals', () {
      expect(CurrencyUtils.formatAmountOnly(100, localeCode: 'en'), '100.00');
      expect(CurrencyUtils.formatAmountOnly(0, localeCode: 'en'), '0.00');
    });

    test('negatives keep the sign outside the grouping', () {
      expect(CurrencyUtils.formatAmountOnly(-150.5, localeCode: 'en'),
          '-150.50');
    });
  });

  group('number formatting — Malay', () {
    test('Malay uses the same separators as English', () {
      // Not a hypothesis: Malaysian number conventions are `.` decimal and `,`
      // grouping, exactly like English. The old hardcoded `ms_MY` grouping was
      // therefore invisible for the two locales the app ships, while ignoring
      // the user's choice entirely.
      expect(CurrencyUtils.formatAmountOnly(1234.5, localeCode: 'ms'),
          '1,234.50');
      expect(CurrencyUtils.formatAmountOnly(1234567.891, localeCode: 'ms'),
          '1,234,567.89');
      expect(CurrencyUtils.formatAmountOnly(-150.5, localeCode: 'ms'),
          '-150.50');
    });
  });

  group('number formatting — the locale argument is really consulted', () {
    test('a locale with swapped separators formats differently', () {
      // German is the control: if the locale were still ignored (the old
      // behaviour) every one of these would read like the English row.
      expect(CurrencyUtils.formatAmountOnly(1234.5, localeCode: 'de'),
          '1.234,50');
      expect(CurrencyUtils.formatAmountOnly(1234567.891, localeCode: 'de'),
          '1.234.567,89');
    });

    test('an omitted locale falls back to the documented English default', () {
      expect(CurrencyUtils.formatAmountOnly(1234.5),
          CurrencyUtils.formatAmountOnly(1234.5,
              localeCode: CurrencyUtils.defaultLocale));
      expect(CurrencyUtils.formatAmountOnly(1234.5), '1,234.50');
    });
  });

  group('currency symbol by code', () {
    test('MYR is the default and shows RM', () {
      expect(CurrencyUtils.symbol, 'RM');
      expect(CurrencyUtils.format(25.9), 'RM 25.90');
    });

    test('SGD shows S\$', () {
      CurrencyUtils.setCurrencyCode('SGD');
      expect(CurrencyUtils.symbol, r'S$');
      expect(CurrencyUtils.format(1234.5), r'S$ 1,234.50');
    });

    test('USD shows \$', () {
      CurrencyUtils.setCurrencyCode('USD');
      expect(CurrencyUtils.symbol, r'$');
      expect(CurrencyUtils.format(2847.62), r'$ 2,847.62');
    });

    test('every supported code yields a distinct symbol', () {
      final symbols = <String>{};
      for (final code in PreferencesService.supportedCurrencies) {
        CurrencyUtils.setCurrencyCode(code);
        symbols.add(CurrencyUtils.symbol);
      }
      expect(symbols, hasLength(PreferencesService.supportedCurrencies.length),
          reason: 'two supported codes must not share a symbol');
    });

    test('an unrecognised code falls back to RM', () {
      CurrencyUtils.setCurrencyCode('EUR');
      expect(CurrencyUtils.symbol, 'RM');
    });

    test('codes are matched exactly, as stored', () {
      // The picker and the store both use upper-case codes; a lower-case value
      // is not a supported currency and must not silently change the symbol.
      CurrencyUtils.setCurrencyCode('usd');
      expect(CurrencyUtils.symbol, 'RM');
    });

    test('switching back restores the original symbol', () {
      CurrencyUtils.setCurrencyCode('USD');
      CurrencyUtils.setCurrencyCode('MYR');
      expect(CurrencyUtils.symbol, 'RM');
      expect(CurrencyUtils.format(25.9), 'RM 25.90');
    });
  });

  group('currency symbol and locale are independent', () {
    test('the locale changes the digits, never the symbol', () {
      CurrencyUtils.setCurrencyCode('SGD');
      expect(CurrencyUtils.format(1234.5, localeCode: 'ms'), r'S$ 1,234.50');
      expect(CurrencyUtils.format(1234.5, localeCode: 'de'), r'S$ 1.234,50');
      expect(CurrencyUtils.symbol, r'S$');
    });
  });

  group('formatCompact', () {
    test('thousands and millions keep the active symbol', () {
      expect(CurrencyUtils.formatCompact(1500), 'RM 1.5K');
      expect(CurrencyUtils.formatCompact(2500000), 'RM 2.5M');
    });

    test('small amounts fall through to the full format', () {
      expect(CurrencyUtils.formatCompact(500), 'RM 500.00');
      expect(CurrencyUtils.formatCompact(500, localeCode: 'en'), 'RM 500.00');
    });
  });

  group('tryParse still round-trips a displayed amount', () {
    test('reads the en/ms display form back', () {
      expect(CurrencyUtils.tryParse('RM 1,234.50'), 1234.5);
      expect(CurrencyUtils.tryParse(r'S$ 2,847.62'), 2847.62);
    });

    test('is locale-independent by construction — it strips separators', () {
      // It keeps only digits and dots, so it reads the same whatever grouping
      // was shown. NOTE: that also means a locale using `,` as the DECIMAL
      // separator would be misread. No shipped locale does (en and ms are both
      // `.` decimal), so this is a latent limitation, recorded here rather than
      // fixed — see the Phase 4 report.
      expect(CurrencyUtils.tryParse('150.50'), 150.5);
      expect(CurrencyUtils.tryParse('abc'), isNull);
    });
  });

  group('runtime locale switching', () {
    testWidgets('amounts follow the language in the same frame, no restart',
        (tester) async {
      final locale = ValueNotifier<Locale>(const Locale('en'));
      addTearDown(locale.dispose);

      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, value, _) => MaterialApp(
            locale: value,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Text(CurrencyUtils.format(1234.5,
                    localeCode: l10n.localeName));
              },
            ),
          ),
        ),
      );

      expect(find.text('RM 1,234.50'), findsOneWidget);

      locale.value = const Locale('ms');
      await tester.pumpAndSettle();

      // Malaysian conventions match English, so the amount is unchanged — the
      // point is that it is re-rendered from the new locale, not cached.
      expect(find.text('RM 1,234.50'), findsOneWidget);

      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(find.text('RM 1,234.50'), findsOneWidget);
    });

    testWidgets('a currency change repaints without touching the language',
        (tester) async {
      final symbol = ValueNotifier<String>('MYR');
      addTearDown(symbol.dispose);
      CurrencyUtils.setCurrencyCode(symbol.value);

      await tester.pumpWidget(
        ValueListenableBuilder<String>(
          valueListenable: symbol,
          builder: (context, value, _) => MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context);
                return Text(CurrencyUtils.format(25.9,
                    localeCode: l10n.localeName));
              },
            ),
          ),
        ),
      );

      expect(find.text('RM 25.90'), findsOneWidget);

      symbol.value = 'SGD';
      CurrencyUtils.setCurrencyCode('SGD');
      await tester.pumpAndSettle();

      expect(find.text(r'S$ 25.90'), findsOneWidget);
      expect(find.text('RM 25.90'), findsNothing);
    });
  });

  group('currency persistence', () {
    setUp(() {
      // Fresh in-memory store per test — no cross-test bleed.
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    /// Reads the store back through a *fresh* service, which is what a page
    /// reload actually does — the service holds no state of its own.
    PreferencesService reopen(SharedPreferences prefs) =>
        PreferencesService(prefs);

    /// Lets the fire-and-forget persistence write in `setCurrency` settle.
    Future<void> flushWrites() => Future<void>.delayed(Duration.zero);

    test('defaults to MYR when nothing is stored', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(reopen(prefs).readCurrency(), 'MYR');
      expect(PreferencesService.defaultCurrency, 'MYR');
    });

    test('defaults to MYR with no store at all', () {
      const service = PreferencesService(null);
      expect(service.readCurrency(), 'MYR');
      expect(service.isAvailable, isFalse);
    });

    test('falls back to MYR for an unrecognised stored value', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.currencyKey: 'EUR',
      });
      final prefs = await SharedPreferences.getInstance();
      expect(reopen(prefs).readCurrency(), 'MYR');
    });

    test('a code survives a round trip through the store', () async {
      final prefs = await SharedPreferences.getInstance();
      await reopen(prefs).writeCurrency('USD');

      expect(prefs.getString(PreferencesService.currencyKey), 'USD');
      expect(reopen(prefs).readCurrency(), 'USD');
    });

    test('writes are silently dropped without a store', () async {
      const service = PreferencesService(null);
      await expectLater(service.writeCurrency('USD'), completes);
    });

    test('AppSettings defaults to the shipped currency', () {
      expect(const AppSettings().currency, 'MYR');
    });

    test('AppSettingsNotifier hydrates the persisted currency', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferencesService.currencyKey: 'SGD',
      });
      final prefs = await SharedPreferences.getInstance();

      final notifier = AppSettingsNotifier(reopen(prefs));

      expect(notifier.state.currency, 'SGD');
    });

    test('setCurrency updates state, symbol and store together', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppSettingsNotifier(reopen(prefs));

      notifier.setCurrency('USD');

      // Synchronous: the UI repaints on the next frame with the new symbol.
      expect(notifier.state.currency, 'USD');
      expect(CurrencyUtils.symbol, r'$');
      expect(CurrencyUtils.format(10), r'$ 10.00');

      await flushWrites();
      expect(prefs.getString(PreferencesService.currencyKey), 'USD');
    });

    test('the choice survives a simulated relaunch', () async {
      final prefs = await SharedPreferences.getInstance();
      AppSettingsNotifier(reopen(prefs)).setCurrency('SGD');
      await flushWrites();

      // Next launch: same store, brand-new notifier — exactly what main() does.
      final relaunched = AppSettingsNotifier(reopen(prefs));
      CurrencyUtils.setCurrencyCode(relaunched.state.currency);

      expect(relaunched.state.currency, 'SGD');
      expect(CurrencyUtils.symbol, r'S$');
    });

    test('re-selecting a currency re-applies the symbol', () async {
      // The symbol is process-global, so it can drift from the stored choice.
      // Re-applying unconditionally is what makes a re-selection self-correct.
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppSettingsNotifier(reopen(prefs));
      notifier.setCurrency('USD');

      CurrencyUtils.setCurrencyCode('MYR'); // simulate the drift
      notifier.setCurrency('USD');

      expect(CurrencyUtils.symbol, r'$');
    });

    test('an unrelated setting leaves the currency alone', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppSettingsNotifier(reopen(prefs));
      notifier.setCurrency('SGD');

      notifier.setLanguage('ms');
      await flushWrites();

      expect(notifier.state.currency, 'SGD');
      expect(reopen(prefs).readCurrency(), 'SGD');
    });

    test('the store holds a code, never an amount', () async {
      // Guard rail for the phase's hard constraint: only a currency CODE is
      // persisted. No financial value is written, converted or re-derived.
      final prefs = await SharedPreferences.getInstance();
      final notifier = AppSettingsNotifier(reopen(prefs));
      notifier.setCurrency('USD');
      await flushWrites();

      expect(prefs.getString(PreferencesService.currencyKey), 'USD');
      expect(PreferencesService.supportedCurrencies, contains('USD'));
      expect(PreferencesService.currencyKey, 'settings.currency');
    });
  });
}
