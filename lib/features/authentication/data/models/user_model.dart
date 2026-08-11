import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';

/// Firestore data model for the `users` collection.
///
/// Handles serialization between Firestore JSON and the domain entity.
class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.email,
    required super.displayName,
    super.photoUrl,
    required super.createdAt,
    super.lastLoginAt,
  });

  /// Creates a [UserModel] from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id);
  }

  /// Creates a [UserModel] from a JSON map.
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (map['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Converts to a JSON map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null
          ? Timestamp.fromDate(lastLoginAt!)
          : null,
    };
  }

  /// Converts to a domain entity (same type — no conversion needed here,
  /// but kept for architectural consistency).
  UserEntity toEntity() => this;

  /// Creates a [UserModel] from a domain [UserEntity].
  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      uid: entity.uid,
      email: entity.email,
      displayName: entity.displayName,
      photoUrl: entity.photoUrl,
      createdAt: entity.createdAt,
      lastLoginAt: entity.lastLoginAt,
    );
  }
}
