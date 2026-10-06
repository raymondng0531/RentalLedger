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

  /// Two snapshots are equal when nothing the app shows or authorizes on
  /// differs ([houseDetailsDiffer]). Comparing the id alone made a Treasurer
  /// transfer or rename of the SAME house compare equal, so Riverpod (which
  /// notifies only when `previous != next`) never rebuilt the screens reading
  /// the current house — they kept the old Treasurer until a reload. Same
  /// reasoning as [UserEntity.==]. The balance is deliberately excluded: it
  /// moves with every transaction and the dashboard reads it live.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HouseEntity &&
          runtimeType == other.runtimeType &&
          !houseDetailsDiffer(this, other);

  @override
  int get hashCode => houseId.hashCode;

  @override
  String toString() => 'HouseEntity(houseId: $houseId, name: $houseName)';
}

/// Whether two snapshots of the current house differ in anything the app
/// shows or authorizes on — a different house, or the same house with a new
/// name, Treasurer, invite code, currency or archive state.
///
/// This is also what [HouseEntity.==] compares. The balance
/// (and `updatedAt`) are deliberately ignored: they move with every money
/// movement, and the dashboard already reads the balance live — treating them
/// as a change would rebuild every house-scoped screen on each deposit.
bool houseDetailsDiffer(HouseEntity? a, HouseEntity? b) {
  if (a == null || b == null) return a != b;
  return a.houseId != b.houseId ||
      a.houseName != b.houseName ||
      a.treasurerId != b.treasurerId ||
      a.inviteCode != b.inviteCode ||
      a.currency != b.currency ||
      a.isArchived != b.isArchived;
}
