import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/dashboard/domain/entities/monthly_summary.dart';

void main() {
  group('MonthlySummary', () {
    test('netFlow is money in minus money out', () {
      const summary = MonthlySummary(
        moneyOut: 500,
        moneyIn: 800,
      );
      expect(summary.netFlow, 300);
    });

    test('negative netFlow when money out exceeds money in', () {
      const summary = MonthlySummary(
        moneyOut: 800,
        moneyIn: 500,
      );
      expect(summary.netFlow, -300);
    });

    test('hasPending when count > 0', () {
      const summary = MonthlySummary(pendingCount: 2, pendingReimbursements: 150);
      expect(summary.hasPending, isTrue);
    });

    test('no pending when count is 0', () {
      const summary = MonthlySummary();
      expect(summary.hasPending, isFalse);
    });

    test('defaults to zero', () {
      const summary = MonthlySummary();
      expect(summary.moneyIn, 0);
      expect(summary.moneyOut, 0);
      expect(summary.pendingReimbursements, 0);
      expect(summary.pendingCount, 0);
    });
  });
}
