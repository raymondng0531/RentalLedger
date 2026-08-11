import 'package:flutter/foundation.dart';

import '../entities/house_entity.dart';
import '../entities/house_member_entity.dart';

/// Abstract repository for house and membership operations.
///
/// Defines the contract the data layer must implement.
abstract class HouseRepository {
  /// A [ValueNotifier] that emits the current house whenever the
  /// authenticated user joins, creates, or leaves a house.
  /// Used by GoRouter's `refreshListenable` for onboarding redirects.
  ValueNotifier<HouseEntity?> get currentHouseNotifier;

  /// Returns the current user's house, or `null` if they haven't joined one.
  HouseEntity? get currentHouse;

  /// Whether the currently authenticated user has joined a house.
  bool get hasHouse;

  /// Loads the user's house after auth is ready.
  /// Must be called after authentication to sync the notifier.
  Future<void> loadUserHouse(String userId);

  /// Clears the current house (e.g. on logout) so a previous session's
  /// house never leaks into the next login.
  Future<void> clearCurrentHouse();

  /// Lists all active houses the user belongs to (for the house switcher).
  Future<List<HouseEntity>> getUserHouses(String userId);

  /// Switches the active house and remembers the choice on the profile.
  Future<void> switchHouse(String userId, String houseId);

  /// Creates a new house. Creator becomes Treasurer.
  ///
  /// Generates a unique invite code automatically.
  /// House starts with RM0.00 balance.
  Future<HouseEntity> createHouse(String houseName, String treasurerId);

  /// Joins an existing house using a valid invite code.
  Future<HouseEntity> joinHouse(String inviteCode, String userId);

  /// Generates a new invite code for the house.
  Future<String> regenerateInviteCode(String houseId);

  /// Fetches all active members of a house.
  Future<List<HouseMemberEntity>> getMembers(String houseId);

  /// Fetches a single member by user ID.
  Future<HouseMemberEntity?> getMember(String houseId, String userId);

  /// Transfers treasurer role to another member.
  Future<void> transferTreasurer(
      String houseId, String currentTreasurerId, String newTreasurerId);

  /// Removes a member from the house.
  Future<void> removeMember(String houseId, String memberId, String requesterId);

  /// Leaves the house. Treasurer must transfer ownership first.
  Future<void> leaveHouse(String houseId, String userId, bool isTreasurer);

  /// Stream of house members for real-time updates.
  Stream<List<HouseMemberEntity>> membersStream(String houseId);

  /// Syncs the user's current display info (name/photo) onto their active
  /// member records, so every page resolving member names reflects changes.
  /// Display-only — no role, ownership or financial data is touched.
  Future<void> updateMemberDisplayInfo({
    required String userId,
    String? displayName,
    String? photoUrl,
  });
}
