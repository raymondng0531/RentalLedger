import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:rental_ledger/features/dashboard/domain/entities/activity_item.dart';

/// Shorthand: an open claim as it appears in the Pending Items list — the only
/// kind of expense this list ever contains (the datasource filters to
/// submitted + approved before it reaches [computePendingSummary]).
ActivityItem _claim(String id, double amount) => ActivityItem(
  id: id,
  type: 'expense',
  title: 'Claim $id',
  amount: amount,
  date: DateTime(2026, 8),
);

void main() {
  group('computePendingSummary', () {
    test('no open claims → nothing pending', () {
      final pending = computePendingSummary(const []);
      expect(pending.total, 0);
      expect(pending.count, 0);
    });

    test('sums the whole open-claims list — submitted AND approved', () {
      // The Pending card totals everything in Pending Items, no matter the
      // claim's stage. 20 + 10 + 12 = 42.
      final pending = computePendingSummary([
        _claim('a', 20), // approved
        _claim('b', 10), // approved
        _claim('c', 12), // submitted
      ]);
      expect(pending.total, 42);
      expect(pending.count, 3);
    });

    test('a single open claim sums to its amount', () {
      final pending = computePendingSummary([_claim('a', 50)]);
      expect(pending.total, 50);
      expect(pending.count, 1);
    });

    test('a claim leaving the open set (paid/rejected) drops the total', () {
      // Paid/rejected claims never enter this list, so they are excluded by
      // construction — the transition from "pending" to "done" simply removes
      // the claim and its amount with it.
      final pending = computePendingSummary([
        _claim('a', 20),
        _claim('b', 10),
      ]);
      expect(pending.total, 30);
      expect(pending.count, 2);
    });

    test('open claims from any month count (not month-scoped)', () {
      // A claim submitted last month but still waiting is still owed today.
      final pending = computePendingSummary([
        _claim('a', 120),
        _claim('b', 30),
      ]);
      expect(pending.total, 150);
      expect(pending.count, 2);
    });
  });
}
