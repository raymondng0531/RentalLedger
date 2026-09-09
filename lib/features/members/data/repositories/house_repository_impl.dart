import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/house_entity.dart';
import '../../domain/entities/house_member_entity.dart';
import '../../domain/repositories/house_repository.dart';
import '../datasources/house_remote_datasource.dart';

/// Implementation of [HouseRepository] backed by Firestore.
class HouseRepositoryImpl implements HouseRepository {
  HouseRepositoryImpl({required HouseRemoteDataSource remoteDataSource})
      : _remote = remoteDataSource {
    // Check for an existing house on init.
    // The actual check happens when the user ID is known.
  }

  final HouseRemoteDataSource _remote;
  final ValueNotifier<HouseEntity?> _currentHouseNotifier =
      ValueNotifier<HouseEntity?>(null);

  @override
  ValueNotifier<HouseEntity?> get currentHouseNotifier => _currentHouseNotifier;

  @override
  HouseEntity? get currentHouse => _currentHouseNotifier.value;

  @override
  bool get hasHouse => _currentHouseNotifier.value != null;

  /// Max house-resolution attempts (including the first) and the pause between
  /// retries. On web the very first Firestore read after sign-in / session
  /// restore can race the auth token reaching the Firestore SDK and be rejected
  /// once; a short bounded retry lets it resolve in-process. This is NOT a
  /// navigation workaround — it only runs after a genuine thrown error, and a
  /// clean `null` ("no active house") still returns immediately so a first-time
  /// user is not delayed before onboarding.
  static const int _maxHouseLoadAttempts = 4;
  static const Duration _houseLoadRetryDelay = Duration(milliseconds: 600);

  /// Must be called after auth is ready — loads the user's house.
  ///
  /// Retries transient read failures (see Issue 1): without this, a single
  /// swallowed error leaves [currentHouseNotifier] null forever, so the router
  /// holds a house-owning user on the Create House screen until a full reload.
  Future<void> loadUserHouse(String userId) async {
    for (var attempt = 1; attempt <= _maxHouseLoadAttempts; attempt++) {
      try {
        final house = await _remote.findHouseByUserId(userId);
        // null is definitive ("no active membership") — no further retry.
        _currentHouseNotifier.value = house;
        return;
      } catch (e) {
        debugPrint(
          '[HouseRepository] loadUserHouse attempt $attempt/$_maxHouseLoadAttempts '
          'failed: $e',
        );
        if (attempt == _maxHouseLoadAttempts) {
          // Give up for now rather than spin forever; the notifier stays null
          // so the guard still shows the onboarding screen on a real failure.
          _currentHouseNotifier.value = null;
          return;
        }
        await Future<void>.delayed(_houseLoadRetryDelay);
      }
    }
  }

  @override
  Future<void> clearCurrentHouse() async {
    _currentHouseNotifier.value = null;
  }

  @override
  Future<List<HouseEntity>> getUserHouses(String userId) async {
    try {
      return await _remote.getUserHouses(userId);
    } catch (e) {
      debugPrint('[HouseRepository] getUserHouses error: $e');
      return [];
    }
  }

  @override
  Future<void> switchHouse(String userId, String houseId) async {
    try {
      await _remote.setActiveHouse(userId, houseId);
      final house = await _remote.getHouse(houseId);
      _currentHouseNotifier.value = house;
    } catch (e) {
      debugPrint('[HouseRepository] switchHouse error: $e');
      throw FirebaseFailure('Failed to switch house.');
    }
  }

  @override
  Future<HouseEntity> createHouse(String houseName, String treasurerId) async {
    try {
      final house = await _remote.createHouse(houseName, treasurerId);
      // Remember this house as the user's active one.
      await _remote.setActiveHouse(treasurerId, house.houseId);
      _currentHouseNotifier.value = house;
      return house;
    } on Failure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure('Failed to create house: ${e.toString()}');
    }
  }

  @override
  Future<HouseEntity> joinHouse(String inviteCode, String userId) async {
    try {
      final house = await _remote.joinHouse(inviteCode, userId);
      // Remember this house as the user's active one.
      await _remote.setActiveHouse(userId, house.houseId);
      _currentHouseNotifier.value = house;
      return house;
    } on Failure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure('Failed to join house: ${e.toString()}');
    }
  }

  @override
  Future<String> regenerateInviteCode(String houseId) async {
    try {
      return await _remote.regenerateInviteCode(houseId);
    } catch (e) {
      throw FirebaseFailure('Failed to regenerate code: ${e.toString()}');
    }
  }

  @override
  Future<List<HouseMemberEntity>> getMembers(String houseId) async {
    try {
      return await _remote.getMembers(houseId);
    } catch (e) {
      throw FirebaseFailure('Failed to load members: ${e.toString()}');
    }
  }

  @override
  Future<HouseMemberEntity?> getMember(String houseId, String userId) async {
    try {
      return await _remote.getMember(houseId, userId);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> transferTreasurer(
      String houseId, String currentTreasurerId, String newTreasurerId) async {
    try {
      await _remote.transferTreasurer(houseId, currentTreasurerId, newTreasurerId);
      // Reload house to get updated treasurer ID.
      final updated = await _remote.getHouse(houseId);
      if (updated != null) {
        _currentHouseNotifier.value = updated;
      }
    } catch (e) {
      throw FirebaseFailure('Failed to transfer: ${e.toString()}');
    }
  }

  @override
  Future<void> removeMember(
      String houseId, String memberId, String requesterId) async {
    try {
      await _remote.removeMember(houseId, memberId, requesterId);
    } catch (e) {
      throw FirebaseFailure('Failed to remove member: ${e.toString()}');
    }
  }

  @override
  Future<void> leaveHouse(
      String houseId, String userId, bool isTreasurer) async {
    if (isTreasurer) {
      throw PermissionFailure(
          'Treasurer must transfer ownership before leaving.');
    }

    try {
      await _remote.leaveHouse(houseId, userId);
      _currentHouseNotifier.value = null;
    } catch (e) {
      throw FirebaseFailure('Failed to leave house: ${e.toString()}');
    }
  }

  @override
  Stream<List<HouseMemberEntity>> membersStream(String houseId) {
    return _remote.membersStream(houseId);
  }

  @override
  Future<void> updateMemberDisplayInfo({
    required String userId,
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      await _remote.updateMemberDisplayInfo(
        userId: userId,
        displayName: displayName,
        photoUrl: photoUrl,
      );
    } catch (e) {
      // Display-only sync — non-critical.
      debugPrint('[HouseRepository] updateMemberDisplayInfo error: $e');
    }
  }

  /// Cleans up.
  void dispose() {
    _currentHouseNotifier.dispose();
  }
}
