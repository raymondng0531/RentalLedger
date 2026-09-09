import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/transaction_entity.dart';

/// Firestore data model for the `transactions` collection.
class TransactionModel extends TransactionEntity {
  const TransactionModel({
    required super.transactionId,
    required super.houseId,
    super.expenseId,
    required super.type,
    required super.amount,
    required super.performedBy,
    super.notes,
    required super.createdAt,
    super.receiptUrl,
    super.paidByUserId,
    super.paymentMethod,
    super.periodLabel,
    super.purpose,
    super.categoryId,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel.fromMap(data, doc.id);
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, String docId) {
    return TransactionModel(
      transactionId: docId,
      houseId: map['houseId'] as String? ?? '',
      expenseId: map['expenseId'] as String?,
      type: map['type'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      performedBy: map['performedBy'] as String? ?? '',
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // Proof / attribution — null when absent (legacy documents load fine).
      receiptUrl: map['receiptUrl'] as String?,
      paidByUserId: map['paidByUserId'] as String?,
      paymentMethod: map['paymentMethod'] as String?,
      periodLabel: map['periodLabel'] as String?,
      purpose: map['purpose'] as String?,
      categoryId: map['categoryId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'houseId': houseId,
      'expenseId': expenseId,
      'type': type,
      'amount': amount,
      'performedBy': performedBy,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      // Proof / attribution (nullable — old readers ignore absent keys).
      'receiptUrl': receiptUrl,
      'paidByUserId': paidByUserId,
      'paymentMethod': paymentMethod,
      'periodLabel': periodLabel,
      'purpose': purpose,
      'categoryId': categoryId,
    };
  }

  TransactionEntity toEntity() => this;
}
