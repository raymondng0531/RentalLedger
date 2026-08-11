import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/house_entity.dart';

/// Firestore data model for the `houses` collection.
class HouseModel extends HouseEntity {
  const HouseModel({
    required super.houseId,
    required super.houseName,
    required super.inviteCode,
    required super.treasurerId,
    super.balance,
    super.currency,
    required super.createdAt,
    super.updatedAt,
    super.isArchived,
  });

  /// Creates a [HouseModel] from a Firestore document.
  factory HouseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HouseModel.fromMap(data, doc.id);
  }

  /// Creates a [HouseModel] from a JSON map.
  factory HouseModel.fromMap(Map<String, dynamic> map, String docId) {
    return HouseModel(
      houseId: map['houseId'] as String? ?? docId,
      houseName: map['houseName'] as String? ?? '',
      inviteCode: map['inviteCode'] as String? ?? '',
      treasurerId: map['treasurerId'] as String? ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'MYR',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      isArchived: map['isArchived'] as bool? ?? false,
    );
  }

  /// Converts to a JSON map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'houseId': houseId,
      'houseName': houseName,
      'inviteCode': inviteCode,
      'treasurerId': treasurerId,
      'balance': balance,
      'currency': currency,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      'isArchived': isArchived,
    };
  }

  /// Converts to domain entity.
  HouseEntity toEntity() => this;

  /// Creates from domain entity.
  factory HouseModel.fromEntity(HouseEntity entity) {
    return HouseModel(
      houseId: entity.houseId,
      houseName: entity.houseName,
      inviteCode: entity.inviteCode,
      treasurerId: entity.treasurerId,
      balance: entity.balance,
      currency: entity.currency,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isArchived: entity.isArchived,
    );
  }
}
