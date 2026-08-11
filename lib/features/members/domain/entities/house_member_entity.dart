/// Domain-level house member entity.
///
/// Represents a user's membership in a house.
class HouseMemberEntity {
  const HouseMemberEntity({
    required this.memberId,
    required this.houseId,
    required this.userId,
    this.role = 'Member',
    required this.joinedAt,
    this.isActive = true,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  final String memberId;
  final String houseId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final bool isActive;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  bool get isTreasurer => role == 'Treasurer';

  /// Creates a copy with updated fields.
  HouseMemberEntity copyWith({
    String? memberId,
    String? houseId,
    String? userId,
    String? role,
    DateTime? joinedAt,
    bool? isActive,
    String? displayName,
    String? email,
    String? photoUrl,
  }) {
    return HouseMemberEntity(
      memberId: memberId ?? this.memberId,
      houseId: houseId ?? this.houseId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      isActive: isActive ?? this.isActive,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseMemberEntity &&
          runtimeType == other.runtimeType &&
          memberId == other.memberId;

  @override
  int get hashCode => memberId.hashCode;

  @override
  String toString() =>
      'HouseMemberEntity(userId: $userId, role: $role)';
}
