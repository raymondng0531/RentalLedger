import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure_codes.dart';
import '../../../../core/utils/member_name_utils.dart';
import '../../../../core/utils/member_profile_sync_utils.dart';
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
      // A genuine read failure (e.g. the Firestore SDK rejecting the request
      // before the just-restored auth token has propagated) must PROPAGATE, not
      // be swallowed as null. `null` is the caller's signal for "this user
      // definitely has no active house" — returning it here for an error would
      // tell the repo the user is house-less, strand them on the Create House
      // screen, and (because nothing re-triggers the load) leave them stuck
      // until a full reload. The repo retries thrown errors in-process instead.
      debugPrint('[HouseDataSource] findHouseByUserId error: $e');
      throw const AppFirebaseException('Failed to load your house.');
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
  ///
  /// The code is validated SERVER-SIDE by the `joinHouse` Cloud Function, which
  /// also writes both membership records. That is not a stylistic choice:
  ///
  ///  * The invite code is the join secret, so looking a house up by it reads a
  ///    house the caller does not belong to — exactly what the tightened rules
  ///    forbid. The lookup cannot be done from a client at all.
  ///  * A membership is an authorization fact. While the client could write its
  ///    own `house_members` row, every membership-based rule was satisfiable by
  ///    the person it was meant to exclude.
  ///
  /// [userId] is retained for signature compatibility but deliberately NOT sent:
  /// the function identifies the caller from their auth token, so a client
  /// cannot join on someone else's behalf.
  Future<HouseModel> joinHouse(String inviteCode, String userId) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('joinHouse');
      final result = await callable.call<Map<String, dynamic>>({
        'inviteCode': inviteCode,
      });

      final houseId = result.data['houseId'] as String?;
      if (houseId == null || houseId.isEmpty) {
        throw const AppFirebaseException('Failed to join house.');
      }

      // The membership exists now, so the rules permit reading the house.
      final house = await getHouse(houseId);
      if (house == null) {
        throw const AppFirebaseException('Failed to join house.');
      }
      return house;
    } on AppFirebaseException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      // Surface the server's own message for the expected rejections; treat
      // anything else as an unexpected failure. Each rejection also carries a
      // stable [FailureCodes] value: the message here is the English
      // explanation a log should show, while the code is what the UI renders
      // in the user's own language.
      switch (e.code) {
        case 'not-found':
          throw const AppFirebaseException(
            'Invalid invite code.',
            code: FailureCodes.houseInvalidCode,
          );
        case 'already-exists':
          throw const AppFirebaseException(
            'You are already a member of this house.',
            code: FailureCodes.houseAlreadyMember,
          );
        case 'unauthenticated':
          throw const AppFirebaseException(
            'Please sign in again.',
            code: FailureCodes.authentication,
          );
        case 'invalid-argument':
          throw const AppFirebaseException(
            'Enter a valid invite code.',
            code: FailureCodes.houseInvalidCode,
          );
        default:
          throw const AppFirebaseException('Failed to join house.');
      }
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

  /// Stream of ALL member records for a house — active AND inactive former
  /// members — merged to one display record per user (active wins).
  ///
  /// Read-only name resolution for historical records. Expenses and
  /// transactions keep only the purchaser's UID, so resolving that UID from
  /// the active-member stream alone shows "Unknown Member" the moment the
  /// person leaves the house. This is the equivalent of [membersStream]
  /// without the activity filter — the same all-records source the Dashboard
  /// already reads for historical activity names. Never used for permissions,
  /// role decisions, or the current member roster.
  Stream<List<HouseMemberEntity>> allMembersStream(String houseId) {
    return _firestore
        .collection(FirestoreConstants.houseMembers)
        .where('houseId', isEqualTo: houseId)
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
          // One display record per user: a removed member who rejoined would
          // otherwise expose duplicate rows for the same UID.
          return mergeMemberRecordsByUser(resolved);
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
  ///
  /// WHICH rows may be written, and WHICH fields each needs, is decided by
  /// [planMemberProfileSync] — only the caller's own ACTIVE rows, only the
  /// fields that actually changed. Inactive rows are historical records and
  /// are never rewritten, and a sync where nothing moved writes nothing at all
  /// rather than issuing a no-op update.
  ///
  /// The query is the caller's own rows by `userId`: `house_members` is
  /// authorized for this shape by the deployed rules, which allow a read when
  /// `resource.data.userId == request.auth.uid`. Do not add a filter that is
  /// not in that rule — the rules evaluate a list, not a filter, so a query
  /// they cannot prove is denied outright.
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

      final patches = {
        for (final patch in planMemberProfileSync(
          userId: userId,
          rows: query.docs.map(HouseMemberModel.fromFirestore).toList(),
          displayName: displayName,
          photoUrl: photoUrl,
        ))
          patch.memberId: patch.fields,
      };

      // Everything already matches the profile — a write here would change
      // nothing but still cost a round trip.
      if (patches.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        final fields = patches[doc.id];
        if (fields == null) continue;
        batch.update(doc.reference, fields);
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
