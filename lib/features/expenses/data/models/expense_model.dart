import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/expense_entity.dart';

/// Firestore data model for the `expenses` collection.
class ExpenseModel extends ExpenseEntity {
  const ExpenseModel({
    required super.expenseId,
    required super.houseId,
    required super.purchasedBy,
    super.approvedBy,
    super.reimbursedBy,
    required super.title,
    super.description,
    required super.categoryId,
    required super.amount,
    super.receiptUrl,
    required super.paymentSource,
    super.status,
    super.rejectReason,
    required super.createdAt,
    super.approvedAt,
    super.paidAt,
    super.updatedAt,
    super.displayName,
  });

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseModel.fromMap(data, doc.id);
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String docId) {
    return ExpenseModel(
      expenseId: docId,
      houseId: map['houseId'] as String? ?? '',
      purchasedBy: map['purchasedBy'] as String? ?? '',
      approvedBy: map['approvedBy'] as String?,
      reimbursedBy: map['reimbursedBy'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      categoryId: map['categoryId'] as String? ?? 'other',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      receiptUrl: map['receiptUrl'] as String?,
      paymentSource: map['paymentSource'] as String? ?? 'personal',
      status: map['status'] as String? ?? 'pending',
      rejectReason: map['rejectReason'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (map['approvedAt'] as Timestamp?)?.toDate(),
      paidAt: (map['paidAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      displayName: map['displayName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'houseId': houseId,
      'purchasedBy': purchasedBy,
      'approvedBy': approvedBy,
      'reimbursedBy': reimbursedBy,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'amount': amount,
      'receiptUrl': receiptUrl,
      'paymentSource': paymentSource,
      'status': status,
      'rejectReason': rejectReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'updatedAt':
          updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  ExpenseEntity toEntity() => this;

  factory ExpenseModel.fromEntity(ExpenseEntity entity) {
    return ExpenseModel(
      expenseId: entity.expenseId,
      houseId: entity.houseId,
      purchasedBy: entity.purchasedBy,
      approvedBy: entity.approvedBy,
      reimbursedBy: entity.reimbursedBy,
      title: entity.title,
      description: entity.description,
      categoryId: entity.categoryId,
      amount: entity.amount,
      receiptUrl: entity.receiptUrl,
      paymentSource: entity.paymentSource,
      status: entity.status,
      rejectReason: entity.rejectReason,
      createdAt: entity.createdAt,
      approvedAt: entity.approvedAt,
      paidAt: entity.paidAt,
      updatedAt: entity.updatedAt,
      displayName: entity.displayName,
    );
  }
}
