/// Domain-level house entity.
///
/// Represents a shared household with a central account.
/// Pure Dart — no Firebase or Flutter dependencies.
class HouseEntity {
  const HouseEntity({
    required this.houseId,
    required this.houseName,
    required this.inviteCode,
    required this.treasurerId,
    this.balance = 0.0,
    this.currency = 'MYR',
    required this.createdAt,
    this.updatedAt,
    this.isArchived = false,
  });

  final String houseId;
  final String houseName;
  final String inviteCode;
  final String treasurerId;
  final double balance;
  final String currency;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isArchived;

  /// Creates a copy with updated fields.
  HouseEntity copyWith({
    String? houseId,
    String? houseName,
    String? inviteCode,
    String? treasurerId,
    double? balance,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
  }) {
    return HouseEntity(
      houseId: houseId ?? this.houseId,
      houseName: houseName ?? this.houseName,
      inviteCode: inviteCode ?? this.inviteCode,
      treasurerId: treasurerId ?? this.treasurerId,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseEntity &&
          runtimeType == other.runtimeType &&
          houseId == other.houseId;

  @override
  int get hashCode => houseId.hashCode;

  @override
  String toString() => 'HouseEntity(houseId: $houseId, name: $houseName)';
}
