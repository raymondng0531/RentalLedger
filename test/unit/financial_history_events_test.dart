import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rental_ledger/features/expenses/domain/entities/bill_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/transaction_entity.dart';
import 'package:rental_ledger/features/history/presentation/providers/history_provider.dart';
import 'package:rental_ledger/features/reports/presentation/providers/reports_provider.dart';

/// The new proof/attribution fields must flow through the pure aggregation
/// layers without changing any existing totals:
///   - History: a Deposit event surfaces WHO actually paid (paidByUserId) while
///     still showing the Treasurer as recorder (userId); legacy deposits (no
///     payer recorded) degrade to the recorder; one money movement stays one
///     event (no duplicates).
///   - Reports: transactions carrying the new fields aggregate to the exact
///     same totals as identical transactions without them.
TransactionEntity _tx({
  required String id,
  required String type,
  required double amount,
  required DateTime createdAt,
  String? notes,
  String? performedBy,
  String? receiptUrl,
  String? paidByUserId,
  String? paymentMethod,
  String? periodLabel,
  String? purpose,
  String? categoryId,
}) =>
    TransactionEntity(
      transactionId: id,
      houseId: 'house1',
      type: type,
      amount: amount,
      performedBy: performedBy ?? 'treasurer-1',
      notes: notes,
      createdAt: createdAt,
      receiptUrl: receiptUrl,
      paidByUserId: paidByUserId,
      paymentMethod: paymentMethod,
      periodLabel: periodLabel,
      purpose: purpose,
      categoryId: categoryId,
    );

void main() {
  // `computeReportsData` renders month abbreviations through `DateFormat`,
  // which needs the locale's symbols loaded. The app gets these from
  // `GlobalMaterialLocalizations`; a pure Dart test has to ask for them.
  setUpAll(initializeDateFormatting);

  group('Deposit history events — payer attribution', () {
    test('payer, proof and period are forwarded; recorder stays userId',
        () {
      final events = buildHistoryEvents(
        expenses: const [],
        transactions: [
          _tx(
            id: 'd1',
            type: 'Deposit',
            amount: 1200,
            createdAt: DateTime(2026, 8, 3, 9, 30),
            paidByUserId: 'member-9',
            receiptUrl: 'https://storage.example.com/proof.jpg',
            paymentMethod: 'Bank Transfer',
            periodLabel: '2026-08',
            purpose: 'Monthly Rental',
          ),
        ],
        bills: const [],
      );

      expect(events, hasLength(1));
      final e = events.single;
      expect(e.type, HistoryEventType.deposit);
      // The member who PHYSICALLY paid the money in.
      expect(e.paidByUserId, 'member-9');
      // The Treasurer who recorded it.
      expect(e.userId, 'treasurer-1');
      expect(e.paymentSource, 'central');
      expect(e.receiptUrl, 'https://storage.example.com/proof.jpg');
      expect(e.paymentMethod, 'Bank Transfer');
      expect(e.periodLabel, '2026-08');
      expect(e.purpose, 'Monthly Rental');
    });

    test('legacy deposit (no payer) shows the recorder and null proof fields',
        () {
      final events = buildHistoryEvents(
        expenses: const [],
        transactions: [
          _tx(
              id: 'd1',
              type: 'Deposit',
              amount: 500,
              createdAt: DateTime(2026, 8, 4)),
        ],
        bills: const [],
      );

      expect(events, hasLength(1));
      final e = events.single;
      // Legacy: no separate payer — the tile falls back to the recorder.
      expect(e.paidByUserId, isNull);
      expect(e.userId, 'treasurer-1');
      expect(e.receiptUrl, isNull);
      expect(e.paymentMethod, isNull);
      expect(e.periodLabel, isNull);
      expect(e.purpose, isNull);
    });

    test('Treasurer paying their own top-up is still exactly ONE event', () {
      final events = buildHistoryEvents(
        expenses: const [],
        transactions: [
          _tx(
              id: 'd1',
              type: 'Deposit',
              amount: 800,
              createdAt: DateTime(2026, 8, 5),
              paidByUserId: 'treasurer-1', // payer == recorder
              receiptUrl: 'https://storage.example.com/proof.jpg',
              purpose: 'General Top-up',
          ),
        ],
        bills: const [],
      );

      expect(events, hasLength(1),
          reason: 'one deposit transaction is one history event');
    });
  });

  group('Direct Payment / Bill Paid history events — proof + period', () {
    test('a bill payment forwards its proof, method and month onto the event',
        () {
      final events = buildHistoryEvents(
        expenses: const [],
        transactions: [
          _tx(
              id: 't1',
              type: 'Direct Payment',
              amount: -120,
              createdAt: DateTime(2026, 8, 6),
              notes: 'Bill: Internet Bill',
              receiptUrl: 'https://storage.example.com/internet.jpg',
              paymentMethod: 'Card',
              periodLabel: '2026-08',
          ),
        ],
        bills: [
          BillEntity(
            billId: 'b1',
            houseId: 'house1',
            title: 'Internet Bill',
            amount: 120,
            dueDate: DateTime(2026, 8),
            createdAt: DateTime(2026, 8),
          ),
        ],
      );

      // One Created + one Paid — never a duplicate of the payment.
      expect(events.where((e) => e.type == HistoryEventType.billCreated),
          hasLength(1));
      final paid =
          events.firstWhere((e) => e.type == HistoryEventType.billPaid);
      expect(paid.receiptUrl, 'https://storage.example.com/internet.jpg');
      expect(paid.paymentMethod, 'Card');
      expect(paid.periodLabel, '2026-08');
      expect(paid.paymentSource, 'central');
      // Category resolved from the matching bill for the chip.
      expect(paid.categoryId, 'utilities');
    });

    test('manual direct payment forwards its own category', () {
      final events = buildHistoryEvents(
        expenses: const [],
        transactions: [
          _tx(
              id: 't1',
              type: 'Direct Payment',
              amount: -350,
              createdAt: DateTime(2026, 8, 7),
              notes: 'Fridge repair',
              categoryId: 'repairs',
          ),
        ],
        bills: const [],
      );

      final e = events.single;
      expect(e.type, HistoryEventType.directPayment);
      expect(e.categoryId, 'repairs');
      expect(e.receiptUrl, isNull); // legacy manual payments have no proof
    });
  });

  group('Reports totals — attribution fields change nothing', () {
    ReportsData reportFor(List<TransactionEntity> transactions) =>
        computeReportsData(
          now: DateTime(2026, 9),
          categoryNames: const {},
          bills: const [],
          transactions: transactions,
          expenses: const [],
        );

    test('a deposit/direct-payment pair with fields totals identical to legacy',
        () {
      final withFields = reportFor([
        _tx(
            id: 'd1',
            type: 'Deposit',
            amount: 1000,
            createdAt: DateTime(2026, 8, 3),
            paidByUserId: 'member-9',
            paymentMethod: 'Bank Transfer',
            periodLabel: '2026-08',
            purpose: 'Monthly Rental',
            receiptUrl: 'https://storage.example.com/proof.jpg'),
        _tx(
            id: 'p1',
            type: 'Direct Payment',
            amount: -120,
            createdAt: DateTime(2026, 8, 4),
            notes: 'Bill: Internet Bill',
            categoryId: 'utilities',
            paymentMethod: 'Card',
            periodLabel: '2026-08',
            receiptUrl: 'https://storage.example.com/internet.jpg'),
      ]);

      final withoutFields = reportFor([
        _tx(
            id: 'd1',
            type: 'Deposit',
            amount: 1000,
            createdAt: DateTime(2026, 8, 3)),
        _tx(
            id: 'p1',
            type: 'Direct Payment',
            amount: -120,
            createdAt: DateTime(2026, 8, 4),
            notes: 'Bill: Internet Bill'),
      ]);

      // Totals are driven by type + amount + date, never by the new fields.
      expect(withFields.totalDeposits, withoutFields.totalDeposits);
      expect(withFields.moneyIn, withoutFields.moneyIn);
      expect(withFields.moneyOut, withoutFields.moneyOut);
      expect(withFields.balance, withoutFields.balance);
      expect(withFields.netFlow, withoutFields.netFlow);
      expect(withFields.moneyOutBreakdown.billPayments,
          withoutFields.moneyOutBreakdown.billPayments);
      expect(withFields.monthlyTrend.first.moneyIn,
          withoutFields.monthlyTrend.first.moneyIn);
      expect(withFields.monthlyTrend.first.moneyOut,
          withoutFields.monthlyTrend.first.moneyOut);

      // Sanity: the numbers themselves are right.
      expect(withFields.moneyIn, 1000);
      expect(withFields.moneyOut, 120);
      expect(withFields.balance, 880);
      expect(withFields.totalDeposits, 1000);
    });
  });
}
