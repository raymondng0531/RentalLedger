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

  /// Compares by full field value — NOT by uid alone.
  ///
  /// The auth repository stores the signed-in user in a [ValueNotifier], whose
  /// setter silently discards a new value that `==` the stored one. If two
  /// entities with the same uid but a different photo/displayName compared
  /// equal, a profile edit would be dropped and the UI would never see it.
  /// Fields that can change on the same account therefore participate here.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserEntity &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          displayName == other.displayName &&
          photoUrl == other.photoUrl &&
          createdAt == other.createdAt &&
          lastLoginAt == other.lastLoginAt;

  @override
  int get hashCode =>
      Object.hash(uid, email, displayName, photoUrl, createdAt, lastLoginAt);

  @override
  String toString() => 'UserEntity(uid: $uid, email: $email, '
      'displayName: $displayName)';
}
