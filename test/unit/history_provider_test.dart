import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/expenses/domain/entities/bill_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/expense_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/transaction_entity.dart';
import 'package:rental_ledger/features/history/presentation/providers/history_provider.dart';

ExpenseEntity _expense({
  required String id,
  required String title,
  required String status,
  required DateTime createdAt,
  DateTime? approvedAt,
  DateTime? paidAt,
  String categoryId = 'food',
}) =>
    ExpenseEntity(
      expenseId: id,
      houseId: 'house1',
      purchasedBy: 'user1',
      title: title,
      categoryId: categoryId,
      amount: 100,
      paymentSource: 'personal',
      status: status,
      approvedAt: approvedAt,
      paidAt: paidAt,
      createdAt: createdAt,
    );

TransactionEntity _tx({
  required String id,
  required String type,
  required double amount,
  required DateTime createdAt,
  String? notes,
}) =>
    TransactionEntity(
      transactionId: id,
      houseId: 'house1',
      type: type,
      amount: amount,
      performedBy: 'user1',
      notes: notes,
      createdAt: createdAt,
    );

BillEntity _bill({
  required String id,
  required String title,
  required DateTime createdAt,
  double? amount,
}) =>
    BillEntity(
      billId: id,
      houseId: 'house1',
      title: title,
      amount: amount,
      dueDate: DateTime(2026, 8, 1),
      createdAt: createdAt,
    );

void main() {
  group('buildHistoryEvents', () {
    test('a paid expense yields ONE Expense Paid event (reimbursement tx hidden)',
        () {
      final events = buildHistoryEvents(
        expenses: [
          _expense(
            id: 'e1',
            title: 'Groceries',
            status: 'paid',
            createdAt: DateTime(2026, 8, 1, 10),
            approvedAt: DateTime(2026, 8, 2, 11),
            paidAt: DateTime(2026, 8, 3, 12),
          ),
        ],
        transactions: [
          _tx(
              id: 'r1',
              type: 'Reimbursement',
              amount: -100,
              createdAt: DateTime(2026, 8, 3, 12)),
        ],
        bills: const [],
      );

      expect(events, hasLength(1),
          reason: 'the reimbursement transaction must not be duplicated');
      expect(events.single.type, HistoryEventType.expensePaid);
      expect(events.single.title, 'Groceries');
      expect(events.single.amount, -100);
      expect(events.single.date, DateTime(2026, 8, 3, 12));
      // Display data for the tile: who, how, and the category.
      expect(events.single.userId, 'user1');
      expect(events.single.paymentSource, 'personal');
      expect(events.single.categoryId, 'food');
      // Navigation target for the tile tap → Expense Details.
      expect(events.single.refId, 'e1');
    });

    test('each expense status maps to its own milestone event', () {
      final events = buildHistoryEvents(
        expenses: [
          _expense(
              id: 'p',
              title: 'Pending one',
              status: 'pending',
              createdAt: DateTime(2026, 8, 1)),
          _expense(
              id: 'a',
              title: 'Approved one',
              status: 'approved',
              createdAt: DateTime(2026, 8, 2),
              approvedAt: DateTime(2026, 8, 5)),
          _expense(
              id: 'pd',
              title: 'Paid one',
              status: 'paid',
              createdAt: DateTime(2026, 8, 3),
              approvedAt: DateTime(2026, 8, 4),
              paidAt: DateTime(2026, 8, 6)),
          _expense(
              id: 'r',
              title: 'Rejected one',
              status: 'rejected',
              createdAt: DateTime(2026, 8, 4),
              approvedAt: DateTime(2026, 8, 7)),
        ],
        transactions: const [],
        bills: const [],
      );

      expect(events, hasLength(4));
      final byId = {for (final e in events) e.id: e};

      expect(byId['exp-submitted-p']!.type, HistoryEventType.expenseSubmitted);
      expect(byId['exp-submitted-p']!.date, DateTime(2026, 8, 1));
      expect(byId['exp-submitted-p']!.status, 'pending');

      expect(byId['exp-approved-a']!.type, HistoryEventType.expenseApproved);
      expect(byId['exp-approved-a']!.date, DateTime(2026, 8, 5));

      expect(byId['exp-paid-pd']!.type, HistoryEventType.expensePaid);
      expect(byId['exp-paid-pd']!.date, DateTime(2026, 8, 6));
      expect(byId['exp-paid-pd']!.amount, -100);

      expect(byId['exp-rejected-r']!.type, HistoryEventType.expenseRejected);
      expect(byId['exp-rejected-r']!.date, DateTime(2026, 8, 7));
    });

    test('a deposit transaction produces a single deposit event', () {
      final events = buildHistoryEvents(
        expenses: const [],
        transactions: [
          _tx(
              id: 'd1',
              type: 'Deposit',
              amount: 500,
              createdAt: DateTime(2026, 8, 5, 10, 35)),
        ],
        bills: const [],
      );

      expect(events, hasLength(1));
      expect(events.single.type, HistoryEventType.deposit);
      expect(events.single.amount, 500);
      expect(events.single.title, isNull);
      // Deposit goes to the central account and shows who recorded it.
      expect(events.single.paymentSource, 'central');
      expect(events.single.userId, 'user1');
    });

    test('bill payment is Bill Paid; a manual payment is Direct Payment', () {
      final events = buildHistoryEvents(
        expenses: const [],
        transactions: [
          _tx(
              id: 't1',
              type: 'Direct Payment',
              amount: -120,
              createdAt: DateTime(2026, 8, 5),
              notes: 'Bill: Internet Bill'),
          _tx(
              id: 't2',
              type: 'Direct Payment',
              amount: -350,
              createdAt: DateTime(2026, 8, 4),
              notes: 'Rent'),
        ],
        bills: const [],
      );

      expect(events, hasLength(2));
      final billPaid =
          events.firstWhere((e) => e.type == HistoryEventType.billPaid);
      expect(billPaid.title, 'Internet Bill');
      expect(billPaid.amount, -120);
      final manual =
          events.firstWhere((e) => e.type == HistoryEventType.directPayment);
      expect(manual.title, 'Rent');
      expect(manual.amount, -350);
    });

    test('a paid bill yields one Created and one Paid event (no duplicates)',
        () {
      final events = buildHistoryEvents(
        expenses: const [],
        transactions: [
          _tx(
              id: 't1',
              type: 'Direct Payment',
              amount: -120,
              createdAt: DateTime(2026, 8, 6),
              notes: 'Bill: Internet Bill'),
        ],
        bills: [
          _bill(
              id: 'b1',
              title: 'Internet Bill',
              createdAt: DateTime(2026, 8, 1),
              amount: 120),
        ],
      );

      expect(events.where((e) => e.type == HistoryEventType.billCreated),
          hasLength(1));
      expect(
          events.where((e) => e.type == HistoryEventType.billPaid), hasLength(1));
      expect(events, hasLength(2));

      // Both bill events resolve the bill's category for the chip.
      final created =
          events.firstWhere((e) => e.type == HistoryEventType.billCreated);
      final paid = events.firstWhere((e) => e.type == HistoryEventType.billPaid);
      expect(created.categoryId, 'utilities');
      expect(paid.categoryId, 'utilities');
      expect(paid.paymentSource, 'central');
    });

    test('a mixed feed never contains duplicate event ids', () {
      final events = buildHistoryEvents(
        expenses: [
          _expense(
              id: 'e1',
              title: 'Groceries',
              status: 'paid',
              createdAt: DateTime(2026, 8, 1),
              approvedAt: DateTime(2026, 8, 2),
              paidAt: DateTime(2026, 8, 3)),
        ],
        transactions: [
          _tx(
              id: 'd1',
              type: 'Deposit',
              amount: 500,
              createdAt: DateTime(2026, 8, 4)),
          _tx(
              id: 'r1',
              type: 'Reimbursement',
              amount: -100,
              createdAt: DateTime(2026, 8, 3)),
          _tx(
              id: 'p1',
              type: 'Direct Payment',
              amount: -350,
              createdAt: DateTime(2026, 8, 5)),
        ],
        bills: [
          _bill(
              id: 'b1',
              title: 'Internet Bill',
              createdAt: DateTime(2026, 8, 1),
              amount: 120),
        ],
      );

      final ids = events.map((e) => e.id).toSet();
      expect(ids.length, events.length, reason: 'every event id must be unique');
      // Groceries appears once (as Expense Paid); its reimbursement tx is hidden.
      expect(
        events.where((e) => e.type == HistoryEventType.expensePaid),
        hasLength(1),
      );
    });
  });
}
