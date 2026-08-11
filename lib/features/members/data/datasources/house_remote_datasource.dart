import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/member_name_utils.dart';
import '../../domain/entities/house_member_entity.dart';
import '../models/house_member_model.dart';
import '../models/house_model.dart';

/// Remote data source for house and membership operations.
///
/// Wraps Firestore calls with error handling.
class HouseRemoteDataSource {
  HouseRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();
  final _random = Random();

  // ───── Houses ─────

  /// Fetches a house document by ID.
  Future<HouseModel?> getHouse(String houseId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreConstants.houses)
          .doc(houseId)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return HouseModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('[HouseDataSource] getHouse error: $e');
      throw const AppFirebaseException('Failed to load house.');
    }
  }

  /// Finds the house a user belongs to by looking up their membership.
  ///
  /// Prefers the user's stored `activeHouseId` so the last-used house
  /// is restored on login. Falls back to the first active membership.
  Future<HouseModel?> findHouseByUserId(String userId) async {
    try {
      // Read the user's stored active house preference.
      String? preferredHouseId;
      try {
        final userDoc = await _firestore
            .collection(FirestoreConstants.users)
            .doc(userId)
            .get();
        preferredHouseId = userDoc.data()?['activeHouseId'] as String?;
      } catch (_) {
        // Ignore — fall back to first membership.
      }

      final membershipQuery = await _firestore
          .collection(FirestoreConstants.houseMembers)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      if (membershipQuery.docs.isEmpty) return null;

      // If the preferred house is still an active membership, use it.
      if (preferredHouseId != null && preferredHouseId.isNotEmpty) {
        final preferredMembership = membershipQuery.docs
            .where((doc) => doc.data()['houseId'] == preferredHouseId)
            .toList();
        if (preferredMembership.isNotEmpty) {
          return getHouse(preferredHouseId);
        }
      }

      // Fall back to the first active membership (stable order by joinedAt).
      membershipQuery.docs.sort((a, b) {
        final aDate = (a.data()['joinedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = (b.data()['joinedAt'] as Timestamp?)?.toDate() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });

      final houseId = membershipQuery.docs.first.data()['houseId'] as String?;
      if (houseId == null) return null;

      // Persist this as the active house.
      await setActiveHouse(userId, houseId);

      return getHouse(houseId);
    } catch (e) {
      debugPrint('[HouseDataSource] findHouseByUserId error: $e');
      return null;
    }
  }

  /// Stores the user's active house preference on their profile.
  Future<void> setActiveHouse(String userId, String houseId) async {
    try {
      await _firestore.collection(FirestoreConstants.users).doc(userId).set({
        'activeHouseId': houseId,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[HouseDataSource] setActiveHouse error: $e');
    }
  }

  /// Lists all active houses a user belongs to (for the house switcher).
  Future<List<HouseModel>> getUserHouses(String userId) async {
    try {
      final membershipQuery = await _firestore
          .collection(FirestoreConstants.houseMembers)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      final houses = <HouseModel>[];
      for (final doc in membershipQuery.docs) {
        final houseId = doc.data()['houseId'] as String?;
        if (houseId == null) continue;
        final house = await getHouse(houseId);
        if (house != null) houses.add(house);
      }
      return houses;
    } catch (e) {
      debugPrint('[HouseDataSource] getUserHouses error: $e');
      return [];
    }
  }

  /// Creates a new house document and the treasurer's membership.
  Future<HouseModel> createHouse(String houseName, String treasurerId) async {
    try {
      final houseId = _uuid.v4();
      final inviteCode = _generateInviteCode();
      final now = DateTime.now();

      final house = HouseModel(
        houseId: houseId,
        houseName: houseName,
        inviteCode: inviteCode,
        treasurerId: treasurerId,
        balance: 0.0,
        currency: 'MYR',
        createdAt: now,
        updatedAt: now,
      );

      // Write house document.
      await _firestore
          .collection(FirestoreConstants.houses)
          .doc(houseId)
          .set(house.toMap());

      // Create treasurer membership.
      await _createMemberRecord(
        houseId: houseId,
        userId: treasurerId,
        role: FirestoreConstants.roleTreasurer,
      );

      return house;
    } catch (e) {
      debugPrint('[HouseDataSource] createHouse error: $e');
      throw const AppFirebaseException('Failed to create house.');
    }
  }

  /// Joins a house using an invite code.
  Future<HouseModel> joinHouse(String inviteCode, String userId) async {
    try {
      // Find house by invite code.
      final query = await _firestore
          .collection(FirestoreConstants.houses)
          .where('inviteCode', isEqualTo: inviteCode)
          .where('isArchived', isEqualTo: false)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw const AppFirebaseException('Invalid invite code.');
      }

      final houseDoc = query.docs.first;
      final house = HouseModel.fromFirestore(houseDoc);

      // Check if user is already a member.
      final existingMembership = await _firestore
          .collection(FirestoreConstants.houseMembers)
          .where('houseId', isEqualTo: house.houseId)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (existingMembership.docs.isNotEmpty) {
        throw const AppFirebaseException(
            'You are already a member of this house.');
      }

      // Create member record.
      await _createMemberRecord(
        houseId: house.houseId,
        userId: userId,
        role: FirestoreConstants.roleMember,
      );

      return house;
    } on AppFirebaseException {
      rethrow;
    } catch (e) {
      debugPrint('[HouseDataSource] joinHouse error: $e');
      throw const AppFirebaseException('Failed to join house.');
    }
  }

  /// Regenerates the invite code for a house.
  Future<String> regenerateInviteCode(String houseId) async {
    final newCode = _generateInviteCode();
    try {
      await _firestore
          .collection(FirestoreConstants.houses)
          .doc(houseId)
          .update({'inviteCode': newCode});
      return newCode;
    } catch (e) {
      debugPrint('[HouseDataSource] regenerateInviteCode error: $e');
      throw const AppFirebaseException('Failed to regenerate invite code.');
    }
  }

  // ───── Members ─────

  /// Stream of active members for a house.
  ///
  /// Resolves display names from the user profiles on each emission, so the
  /// UI never shows "Unknown Member" for a member record that predates a
  /// profile name. Read-only — names are persisted by [getMembers].
  Stream<List<HouseMemberEntity>> membersStream(String houseId) {
    return _firestore
        .collection(FirestoreConstants.houseMembers)
        .where('houseId', isEqualTo: houseId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final members = snapshot.docs
              .map((doc) => HouseMemberModel.fromFirestore(doc))
              .toList();
          final resolved = <HouseMemberEntity>[];
          for (final member in members) {
            final name = await resolveMemberDisplayName(
              _firestore,
              userId: member.userId,
              memberDisplayName: member.displayName,
              memberEmail: member.email,
            );
            resolved.add(
              name != null ? member.copyWith(displayName: name) : member,
            );
          }
          return resolved;
        });
  }

  /// Fetches all active members, backfilling missing display names from the
  /// user profiles so every page resolves the same name.
  Future<List<HouseMemberEntity>> getMembers(String houseId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreConstants.houseMembers)
          .where('houseId', isEqualTo: houseId)
          .where('isActive', isEqualTo: true)
          .get();

      final members = snapshot.docs
          .map((doc) => HouseMemberModel.fromFirestore(doc))
          .toList();

      // Backfill display names for members missing them (older records that
      // predate a profile name). A missing email must not block the backfill.
      // Persist the resolved name so future reads are fast, and return the
      // enriched model (previously the in-memory models were left stale).
      final resolved = <HouseMemberEntity>[];
      for (final member in members) {
        final name = await resolveMemberDisplayName(
          _firestore,
          userId: member.userId,
          memberDisplayName: member.displayName,
          memberEmail: member.email,
        );
        if (name == null) {
          resolved.add(member);
          continue;
        }
        if (name != member.displayName) {
          try {
            await _firestore
                .collection(FirestoreConstants.houseMembers)
                .doc(member.memberId)
                .update({'displayName': name});
          } catch (_) {
            // Non-critical.
          }
        }
        resolved.add(member.copyWith(displayName: name));
      }

      return resolved;
    } catch (e) {
      debugPrint('[HouseDataSource] getMembers error: $e');
      throw const AppFirebaseException('Failed to load members.');
    }
  }

  /// Syncs a user's display info (name/photo) onto their active member
  /// records across all their houses. Keeps the member list, History and
  /// Dashboard name resolution in step with the profile. Display-only.
  ///
  /// All member-record writes go through a single Firestore batch so the
  /// cross-house sync is atomic — the user can never see a house with the new
  /// name and another with the old one.
  Future<void> updateMemberDisplayInfo({
    required String userId,
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      final query = await _firestore
          .collection(FirestoreConstants.houseMembers)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      if (query.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {
          if (displayName != null) 'displayName': displayName,
          if (photoUrl != null) 'photoUrl': photoUrl,
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[HouseDataSource] updateMemberDisplayInfo error: $e');
    }
  }

  /// Fetches a single member by user ID.
  Future<HouseMemberModel?> getMember(String houseId, String userId) async {
    try {
      final query = await _firestore
          .collection(FirestoreConstants.houseMembers)
          .where('houseId', isEqualTo: houseId)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return HouseMemberModel.fromFirestore(query.docs.first);
    } catch (e) {
      debugPrint('[HouseDataSource] getMember error: $e');
      return null;
    }
  }

  /// Transfers treasurer role.
  Future<void> transferTreasurer(
      String houseId, String currentTreasurerId,
      String newTreasurerId) async {
    try {
      // Update current treasurer → Member.
      final currentQuery = await _firestore
          .collection(FirestoreConstants.houseMembers)
          .where('houseId', isEqualTo: houseId)
          .where('userId', isEqualTo: currentTreasurerId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (currentQuery.docs.isNotEmpty) {
        await currentQuery.docs.first.reference.update({
          'role': FirestoreConstants.roleMember,
        });
      }

      // Update new treasurer → Treasurer.
      final newQuery = await _firestore
          .collection(FirestoreConstants.houseMembers)
          .where('houseId', isEqualTo: houseId)
          .where('userId', isEqualTo: newTreasurerId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (newQuery.docs.isNotEmpty) {
        await newQuery.docs.first.reference.update({
          'role': FirestoreConstants.roleTreasurer,
        });
      }

      // Update house document.
      await _firestore
          .collection(FirestoreConstants.houses)
          .doc(houseId)
          .update({
        'treasurerId': newTreasurerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[HouseDataSource] transferTreasurer error: $e');
      throw const AppFirebaseException('Failed to transfer treasurer role.');
    }
  }

  /// Removes a member (soft delete).
  Future<void> removeMember(
      String houseId, String memberId, String requesterId) async {
    try {
      await _firestore
          .collection(FirestoreConstants.houseMembers)
          .doc(memberId)
          .update({'isActive': false});
    } catch (e) {
      debugPrint('[HouseDataSource] removeMember error: $e');
      throw const AppFirebaseException('Failed to remove member.');
    }
  }

  /// Leaves a house (soft delete).
  Future<void> leaveHouse(String houseId, String userId) async {
    try {
      final query = await _firestore
          .collection(FirestoreConstants.houseMembers)
          .where('houseId', isEqualTo: houseId)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({'isActive': false});
      }
    } catch (e) {
      debugPrint('[HouseDataSource] leaveHouse error: $e');
      throw const AppFirebaseException('Failed to leave house.');
    }
  }

  // ───── Helpers ─────

  /// Creates a member record in Firestore.
  /// Fetches the user's profile so the member list shows their real name.
  Future<void> _createMemberRecord({
    required String houseId,
    required String userId,
    String role = 'Member',
  }) async {
    final memberId = _uuid.v4();

    // Fetch the user's profile to populate display info.
    String? displayName;
    String? email;
    String? photoUrl;
    try {
      final userDoc = await _firestore
          .collection(FirestoreConstants.users)
          .doc(userId)
          .get();
      final data = userDoc.data();
      if (data != null) {
        displayName = data['displayName'] as String?;
        email = data['email'] as String?;
        photoUrl = data['photoUrl'] as String?;
      }
    } catch (_) {
      // Non-critical — member record will just lack display info.
    }

    final member = HouseMemberModel(
      memberId: memberId,
      houseId: houseId,
      userId: userId,
      role: role,
      joinedAt: DateTime.now(),
      isActive: true,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
    );

    await _firestore
        .collection(FirestoreConstants.houseMembers)
        .doc(memberId)
        .set(member.toMap());
  }

  /// Generates a unique 8-character invite code.
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(8, (_) {
      return chars[_random.nextInt(chars.length)];
    }).join();
  }
}
