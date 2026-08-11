import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:rental_ledger/features/dashboard/domain/entities/activity_item.dart';

ActivityItem _item(String id, DateTime date, {String type = 'expense'}) =>
    ActivityItem(
      id: id,
      type: type,
      title: 'Item $id',
      amount: 100,
      date: date,
    );

void main() {
  group('expenseActivityDate', () {
    final created = DateTime(2026, 8);
    final approved = DateTime(2026, 8, 5);
    final paid = DateTime(2026, 8, 8);

    test('paid expenses sort by paidAt (latest milestone)', () {
      expect(
        expenseActivityDate(
          status: 'paid',
          createdAt: created,
          approvedAt: approved,
          paidAt: paid,
        ),
        paid,
      );
    });

    test('paid expenses fall back to approvedAt / createdAt', () {
      expect(
        expenseActivityDate(status: 'paid', createdAt: created, approvedAt: approved),
        approved,
      );
      expect(
        expenseActivityDate(status: 'paid', createdAt: created),
        created,
      );
    });

    test('approved expenses sort by approvedAt', () {
      expect(
        expenseActivityDate(status: 'approved', createdAt: created, approvedAt: approved),
        approved,
      );
      expect(
        expenseActivityDate(status: 'approved', createdAt: created),
        created,
      );
    });

    test('rejected expenses surface at the rejection time (approvedAt)', () {
      // A rejection just now must appear at the TOP of the feed, not at the
      // expense's original createdAt position.
      final rejectionTime = DateTime(2026, 8, 11, 17, 36);
      expect(
        expenseActivityDate(
          status: 'rejected',
          createdAt: created,
          approvedAt: rejectionTime,
        ),
        rejectionTime,
      );
    });

    test('pending expenses use createdAt', () {
      expect(
        expenseActivityDate(status: 'pending', createdAt: created),
        created,
      );
    });
  });

  group('mergeRecentActivity', () {
    test('merges transactions and expenses newest-first', () {
      final merged = mergeRecentActivity(
        [_item('t1', DateTime(2026, 8), type: 'deposit')],
        [_item('e1', DateTime(2026, 8, 3)), _item('e2', DateTime(2026, 8, 2))],
      );

      expect(merged.map((i) => i.id), ['e1', 'e2', 't1']);
    });

    test('caps the combined feed at the limit (default 20)', () {
      final expenses = [
        for (var i = 0; i < 20; i++)
          _item('e$i', DateTime(2026, 8).add(Duration(days: i))),
      ];
      final transactions = [
        for (var i = 0; i < 20; i++)
          _item('t$i', DateTime(2026, 9).add(Duration(days: i)),
              type: 'deposit'),
      ];

      final merged = mergeRecentActivity(transactions, expenses);
      expect(merged, hasLength(20));
      // The 20 newest are all September transactions.
      expect(merged.every((i) => i.type == 'deposit'), isTrue);
    });

    test('respects a custom limit', () {
      final merged = mergeRecentActivity(
        [_item('t1', DateTime(2026, 8))],
        [_item('e1', DateTime(2026, 8, 3)), _item('e2', DateTime(2026, 8, 2))],
        limit: 2,
      );
      expect(merged.map((i) => i.id), ['e1', 'e2']);
    });

    test('empty inputs produce an empty feed', () {
      expect(mergeRecentActivity([], []), isEmpty);
    });
  });
}
