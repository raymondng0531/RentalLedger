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

  /// Whether this session's house lookup has finished — the third state the
  /// router needs, which [currentHouse] alone cannot express.
  ///
  /// `null` means BOTH "not looked up yet" and "looked up, and this user has no
  /// house". Deciding onboarding on `null` alone is what showed Create House to
  /// a returning member before their Dashboard, so the router reads this
  /// instead: `false` → the answer is still unknown and no onboarding decision
  /// may be made; `true` → resolution finished, and [currentHouse] is the
  /// answer (a house, or definitively none).
  ///
  /// Starts `false` — nothing is resolved on a cold start, which is what closes
  /// the window between session restore and the lookup starting. Flips to `true`
  /// exactly once per resolution, on every way out of it: a house, a definitive
  /// no-house result, or retry exhaustion. Returns to `false` whenever the
  /// session's house is cleared, so the next session resolves for itself.
  ValueNotifier<bool> get houseResolvedNotifier;

  /// Synchronous snapshot of [houseResolvedNotifier].
  bool get isHouseResolved;

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

  /// Stream of ALL member records (active AND inactive former members), merged
  /// to one display record per user (active wins). Read-only name resolution
  /// for historical records — removing a member must never blank their past
  /// expenses/transactions. Never used for the current member roster, roles or
  /// permissions.
  Stream<List<HouseMemberEntity>> allMembersStream(String houseId);

  /// Syncs the user's current display info (name/photo) onto their active
  /// member records, so every page resolving member names reflects changes.
  /// Display-only — no role, ownership or financial data is touched.
  Future<void> updateMemberDisplayInfo({
    required String userId,
    String? displayName,
    String? photoUrl,
  });
}
