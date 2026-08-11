import 'package:intl/intl.dart';

/// Currency formatting utilities.
///
/// Defaults to MYR (RM). The symbol can be switched at runtime via
/// [setCurrencyCode] (wired to the Settings currency picker).
class CurrencyUtils {
  CurrencyUtils._();

  static String _symbol = 'RM';

  /// Sets the currency symbol used by [format] / [formatCompact].
  /// Supported codes: MYR, SGD, USD (anything else falls back to RM).
  static void setCurrencyCode(String code) {
    _symbol = switch (code) {
      'SGD' => r'S$',
      'USD' => r'$',
      _ => 'RM',
    };
  }

  /// Formats [amount] as a currency string.
  /// Example: `RM 1,234.56`
  static String format(double amount) {
    return '$_symbol ${formatAmountOnly(amount)}';
  }

  /// Formats [amount] without the currency symbol.
  /// Example: `1,234.56`
  static String formatAmountOnly(double amount) {
    final formatter = NumberFormat('#,##0.00', 'ms_MY');
    return formatter.format(amount);
  }

  /// Formats [amount] as a compact string for dashboard cards.
  /// Example: `RM 1.2K`
  static String formatCompact(double amount) {
    if (amount >= 1000000) {
      return '$_symbol ${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$_symbol ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }

  /// Parses a currency string back to a double.
  /// Returns `null` if parsing fails.
  static double? tryParse(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned);
  }
}
