import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/utils/currency_utils.dart';

void main() {
  // The symbol is process-global, so pin it to the shipped default rather than
  // relying on no other test in this file having changed it. Locale-aware
  // number/currency behaviour is covered in `phase4_currency_test.dart`.
  setUp(() => CurrencyUtils.setCurrencyCode('MYR'));

  group('CurrencyUtils.format', () {
    test('formats positive amounts with RM symbol', () {
      expect(CurrencyUtils.format(2847.62), 'RM 2,847.62');
    });

    test('formats zero', () {
      expect(CurrencyUtils.format(0), 'RM 0.00');
    });

    test('formats negative amounts', () {
      expect(CurrencyUtils.format(-150.50), 'RM -150.50');
    });

    test('formats whole numbers with decimals', () {
      expect(CurrencyUtils.format(100), 'RM 100.00');
    });
  });

  group('CurrencyUtils.formatAmountOnly', () {
    test('formats without currency symbol', () {
      expect(CurrencyUtils.formatAmountOnly(1234.5), '1,234.50');
    });
  });

  group('CurrencyUtils.formatCompact', () {
    test('formats thousands as K', () {
      expect(CurrencyUtils.formatCompact(1500), 'RM 1.5K');
    });

    test('formats small amounts normally', () {
      expect(CurrencyUtils.formatCompact(500), 'RM 500.00');
    });
  });

  group('CurrencyUtils.tryParse', () {
    test('parses valid currency strings', () {
      expect(CurrencyUtils.tryParse('RM 25.90'), 25.90);
    });

    test('parses plain numbers', () {
      expect(CurrencyUtils.tryParse('100'), 100.0);
    });

    test('returns null for invalid input', () {
      expect(CurrencyUtils.tryParse('abc'), isNull);
    });
  });
}
