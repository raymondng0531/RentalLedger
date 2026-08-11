import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/house_member_entity.dart';

/// Firestore data model for the `house_members` collection.
class HouseMemberModel extends HouseMemberEntity {
  const HouseMemberModel({
    required super.memberId,
    required super.houseId,
    required super.userId,
    super.role,
    required super.joinedAt,
    super.isActive,
    super.displayName,
    super.email,
    super.photoUrl,
  });

  /// Creates from a Firestore document.
  factory HouseMemberModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HouseMemberModel.fromMap(data, doc.id);
  }

  /// Creates from a JSON map.
  factory HouseMemberModel.fromMap(Map<String, dynamic> map, String docId) {
    return HouseMemberModel(
      memberId: map['memberId'] as String? ?? docId,
      houseId: map['houseId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      role: map['role'] as String? ?? 'Member',
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] as bool? ?? true,
      displayName: map['displayName'] as String?,
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
    );
  }

  /// Converts to a JSON map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'houseId': houseId,
      'userId': userId,
      'role': role,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isActive': isActive,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
    };
  }

  /// Converts to domain entity.
  HouseMemberEntity toEntity() => this;

  /// Creates from domain entity.
  factory HouseMemberModel.fromEntity(HouseMemberEntity entity) {
    return HouseMemberModel(
      memberId: entity.memberId,
      houseId: entity.houseId,
      userId: entity.userId,
      role: entity.role,
      joinedAt: entity.joinedAt,
      isActive: entity.isActive,
      displayName: entity.displayName,
      email: entity.email,
      photoUrl: entity.photoUrl,
    );
  }
}
