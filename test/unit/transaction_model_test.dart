import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/expenses/data/models/transaction_model.dart';

/// Proof/attribution fields must survive a Firestore round-trip, and documents
/// written BEFORE those fields existed (legacy) must still load — the fields
/// are all nullable and read with null-tolerant casts.
void main() {
  const docId = 'tx-legacy-1';

  final createdAt = DateTime(2026, 1, 15, 10, 30);

  test('full round-trip preserves every proof/attribution field', () {
    final model = TransactionModel(
      transactionId: docId,
      houseId: 'house1',
      expenseId: 'exp-1',
      type: 'Deposit',
      amount: 1200,
      performedBy: 'treasurer-1',
      notes: 'Sep rental contribution',
      createdAt: createdAt,
      receiptUrl: 'https://storage.example.com/receipts/house1/proof.jpg',
      paidByUserId: 'member-9',
      paymentMethod: 'Bank Transfer',
      periodLabel: '2026-09',
      purpose: 'Monthly Rental',
    );

    final decoded = TransactionModel.fromMap(model.toMap(), docId);

    expect(decoded.transactionId, docId);
    expect(decoded.houseId, 'house1');
    expect(decoded.expenseId, 'exp-1');
    expect(decoded.type, 'Deposit');
    expect(decoded.amount, 1200);
    expect(decoded.performedBy, 'treasurer-1');
    expect(decoded.notes, 'Sep rental contribution');
    expect(decoded.createdAt, createdAt);
    // ── New proof / attribution fields ──
    expect(
      decoded.receiptUrl,
      'https://storage.example.com/receipts/house1/proof.jpg',
    );
    expect(decoded.paidByUserId, 'member-9');
    expect(decoded.paymentMethod, 'Bank Transfer');
    expect(decoded.periodLabel, '2026-09');
    expect(decoded.purpose, 'Monthly Rental');
    expect(decoded.categoryId, isNull);
  });

  test('direct payment category and bill-period fields round-trip', () {
    final model = TransactionModel(
      transactionId: docId,
      houseId: 'house1',
      type: 'Direct Payment',
      amount: -99,
      performedBy: 'treasurer-1',
      notes: 'Bill: Internet Bill',
      createdAt: createdAt,
      receiptUrl: 'https://storage.example.com/receipts/house1/internet.jpg',
      paymentMethod: 'Card',
      periodLabel: '2026-08',
      categoryId: 'utilities',
    );

    final decoded = TransactionModel.fromMap(model.toMap(), docId);
    expect(decoded.receiptUrl, isNotNull);
    expect(decoded.paymentMethod, 'Card');
    expect(decoded.periodLabel, '2026-08');
    expect(decoded.categoryId, 'utilities');
    expect(decoded.paidByUserId, isNull);
    expect(decoded.purpose, isNull);
  });

  test('legacy document (no proof/attribution keys) loads with nulls', () {
    final map = <String, dynamic>{
      'houseId': 'house1',
      'type': 'Deposit',
      'amount': 500.0,
      'performedBy': 'user1',
      'createdAt': Timestamp.fromDate(createdAt),
      // No receiptUrl / paidByUserId / paymentMethod / periodLabel / purpose
      // / categoryId / expenseId / notes — exactly what pre-upgrade docs have.
    };

    final decoded = TransactionModel.fromMap(map, docId);

    expect(decoded.type, 'Deposit');
    expect(decoded.amount, 500);
    expect(decoded.performedBy, 'user1');
    expect(decoded.createdAt, createdAt);
    // New fields must degrade gracefully — never throw, never fabricate data.
    expect(decoded.receiptUrl, isNull);
    expect(decoded.paidByUserId, isNull);
    expect(decoded.paymentMethod, isNull);
    expect(decoded.periodLabel, isNull);
    expect(decoded.purpose, isNull);
    expect(decoded.categoryId, isNull);
    expect(decoded.expenseId, isNull);
    expect(decoded.notes, isNull);
  });
}
