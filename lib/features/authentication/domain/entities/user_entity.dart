/// Domain-level user entity.
///
/// Represents an authenticated user in the system.
/// This is pure Dart — no Firebase or Flutter dependencies.
class UserEntity {
  const UserEntity({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.createdAt,
    this.lastLoginAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  /// Creates a copy with updated fields.
  UserEntity copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserEntity(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'UserEntity(uid: $uid, email: $email, '
      'displayName: $displayName)';
}
