import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/bill_entity.dart';

/// Firestore data model for the `bills` collection.
class BillModel extends BillEntity {
  const BillModel({
    required super.billId,
    required super.houseId,
    required super.title,
    super.amount,
    required super.dueDate,
    super.categoryId,
    super.isActive,
    super.isRecurring,
    super.reminderEnabled,
    super.isPaid,
    required super.createdAt,
  });

  factory BillModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BillModel.fromMap(data, doc.id);
  }

  factory BillModel.fromMap(Map<String, dynamic> map, String docId) {
    return BillModel(
      billId: docId,
      houseId: map['houseId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble(),
      dueDate: (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      categoryId: map['categoryId'] as String? ?? 'utilities',
      isActive: map['isActive'] as bool? ?? true,
      isRecurring: map['isRecurring'] as bool? ?? false,
      reminderEnabled: map['reminderEnabled'] as bool? ?? false,
      isPaid: map['isPaid'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'houseId': houseId,
      'title': title,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'categoryId': categoryId,
      'isActive': isActive,
      'isRecurring': isRecurring,
      'reminderEnabled': reminderEnabled,
      'isPaid': isPaid,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  BillEntity toEntity() => this;

  factory BillModel.fromEntity(BillEntity entity) {
    return BillModel(
      billId: entity.billId,
      houseId: entity.houseId,
      title: entity.title,
      amount: entity.amount,
      dueDate: entity.dueDate,
      categoryId: entity.categoryId,
      isActive: entity.isActive,
      isRecurring: entity.isRecurring,
      reminderEnabled: entity.reminderEnabled,
      isPaid: entity.isPaid,
      createdAt: entity.createdAt,
    );
  }
}
