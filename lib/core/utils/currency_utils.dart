import 'package:intl/intl.dart';

/// Currency formatting utilities.
///
/// Defaults to MYR (RM). The symbol can be switched at runtime via
/// [setCurrencyCode] (wired to the Settings currency picker).
class CurrencyUtils {
  CurrencyUtils._();

  /// The locale used when a caller has none to offer.
  ///
  /// Explicit and deterministic. The previous implementation hardcoded
  /// `'ms_MY'` for the number grouping, which was wrong for every user who did
  /// not ask for Malay — the grouping rule was applied regardless of the
  /// language on screen. Neither `Intl.defaultLocale` nor the platform locale is
  /// consulted here, so the output never depends on the machine running it.
  static const String defaultLocale = 'en';

  static String _symbol = 'RM';

  /// Sets the currency symbol used by [format] / [formatCompact].
  /// Supported codes: MYR, SGD, USD (anything else falls back to RM).
  ///
  /// Process-global mutable state, by design: it is the app-wide currency
  /// choice, not a per-widget one. `main()` applies the persisted choice before
  /// `runApp` so the first frame is already correct, and
  /// [AppSettingsNotifier.setCurrency] keeps it in step afterwards.
  static void setCurrencyCode(String code) {
    _symbol = switch (code) {
      'SGD' => r'S$',
      'USD' => r'$',
      _ => 'RM',
    };
  }

  /// The symbol currently in use, for callers that need it on its own.
  static String get symbol => _symbol;

  /// Formats [amount] as a currency string.
  /// Example: `RM 1,234.56`
  ///
  /// [localeCode] selects the number conventions (grouping separator, decimal
  /// separator). It is optional because the amount is sometimes rendered on a
  /// path with no [BuildContext] available — see [formatAmountOnly].
  static String format(double amount, {String? localeCode}) {
    return '$_symbol ${formatAmountOnly(amount, localeCode: localeCode)}';
  }

  /// Formats [amount] without the currency symbol.
  /// Example: `1,234.56`
  ///
  /// [localeCode] is optional and falls back to [defaultLocale]. The fallback
  /// exists because three call sites — the balance guard's refusal message in
  /// `financial_guards.dart` — run inside a Firestore transaction body, where
  /// there is no `BuildContext` and threading one down would mean pushing a
  /// presentation concern through the money-write path. Those messages are the
  /// same deferred, untranslated domain strings the app already ships (see
  /// `failures.dart`), so they get the documented English fallback rather than
  /// a redesign. Every call site that has a context passes its locale.
  static String formatAmountOnly(double amount, {String? localeCode}) {
    final formatter = NumberFormat('#,##0.00', localeCode ?? defaultLocale);
    return formatter.format(amount);
  }

  /// Formats [amount] as a compact string for dashboard cards.
  /// Example: `RM 1.2K`
  static String formatCompact(double amount, {String? localeCode}) {
    if (amount >= 1000000) {
      return '$_symbol ${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$_symbol ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount, localeCode: localeCode);
  }

  /// Parses a currency string back to a double.
  /// Returns `null` if parsing fails.
  ///
  /// Locale-independent: it strips everything that is not a digit or a dot, so
  /// it reads the same regardless of which separators were displayed.
  static double? tryParse(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned);
  }
}
