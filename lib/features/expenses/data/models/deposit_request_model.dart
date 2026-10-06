import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/deposit_request_entity.dart';

/// Firestore data model for the `deposit_requests` collection.
class DepositRequestModel extends DepositRequestEntity {
  const DepositRequestModel({
    required super.requestId,
    required super.houseId,
    required super.amount,
    required super.paidByUserId,
    required super.submittedBy,
    super.paymentMethod,
    super.periodLabel,
    super.purpose,
    super.notes,
    super.receiptUrl,
    super.status,
    super.rejectReason,
    super.reviewedBy,
    super.reviewedAt,
    super.transactionId,
    required super.createdAt,
  });

  factory DepositRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DepositRequestModel.fromMap(data, doc.id);
  }

  factory DepositRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    final submittedBy = map['submittedBy'] as String? ?? '';
    return DepositRequestModel(
      requestId: docId,
      houseId: map['houseId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paidByUserId: map['paidByUserId'] as String? ?? submittedBy,
      submittedBy: submittedBy,
      paymentMethod: map['paymentMethod'] as String?,
      periodLabel: map['periodLabel'] as String?,
      purpose: map['purpose'] as String?,
      notes: map['notes'] as String?,
      receiptUrl: map['receiptUrl'] as String?,
      status: map['status'] as String? ?? DepositRequestEntity.statusPending,
      rejectReason: map['rejectReason'] as String?,
      reviewedBy: map['reviewedBy'] as String?,
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
      transactionId: map['transactionId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// The document as first written by the submitting member. Review fields
  /// are written as null so the shape is stable; the rules require a new
  /// request to carry none of them.
  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'houseId': houseId,
      'amount': amount,
      'paidByUserId': paidByUserId,
      'submittedBy': submittedBy,
      'paymentMethod': paymentMethod,
      'periodLabel': periodLabel,
      'purpose': purpose,
      'notes': notes,
      'receiptUrl': receiptUrl,
      'status': status,
      'rejectReason': rejectReason,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
      'transactionId': transactionId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
