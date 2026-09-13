import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/house_entity.dart';
import '../../domain/entities/house_member_entity.dart';
import '../../domain/repositories/house_repository.dart';
import '../datasources/house_remote_datasource.dart';

/// Implementation of [HouseRepository] backed by Firestore.
class HouseRepositoryImpl implements HouseRepository {
  HouseRepositoryImpl({
    required HouseRemoteDataSource remoteDataSource,
    Duration attemptTimeout = _defaultAttemptTimeout,
  })  : _remote = remoteDataSource,
        _attemptTimeout = attemptTimeout {
    // Check for an existing house on init.
    // The actual check happens when the user ID is known.
  }

  final HouseRemoteDataSource _remote;

  /// How long one lookup attempt may take — see [_defaultAttemptTimeout].
  /// A parameter so the bound itself is testable without waiting it out.
  final Duration _attemptTimeout;
  final ValueNotifier<HouseEntity?> _currentHouseNotifier =
      ValueNotifier<HouseEntity?>(null);

  /// Starts `false`: on a cold start the lookup has not run yet, and the router
  /// must treat "not looked up" as unknown rather than as "no house".
  final ValueNotifier<bool> _houseResolvedNotifier =
      ValueNotifier<bool>(false);

  /// Bumped by every session change (a new lookup, or a clear). A lookup whose
  /// session has since moved on must not write its result into the new one —
  /// otherwise a late answer for the previous user could land as the current
  /// user's house, or mark the new session resolved before it has been.
  int _resolutionGeneration = 0;

  @override
  ValueNotifier<HouseEntity?> get currentHouseNotifier => _currentHouseNotifier;

  @override
  ValueNotifier<bool> get houseResolvedNotifier => _houseResolvedNotifier;

  @override
  bool get isHouseResolved => _houseResolvedNotifier.value;

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

  /// Ceiling on a single attempt. A read that never answers would leave this
  /// loop — and so the resolution state — pending forever, which would hold the
  /// user on the splash with no way forward. Timing out routes it into the
  /// existing retry/exhaustion path instead, so every attempt ends in a
  /// definitive answer.
  static const Duration _defaultAttemptTimeout = Duration(seconds: 10);

  /// Must be called after auth is ready — loads the user's house.
  ///
  /// Retries transient read failures (see Issue 1): without this, a single
  /// swallowed error leaves [currentHouseNotifier] null forever, so the router
  /// holds a house-owning user on the Create House screen until a full reload.
  ///
  /// Every exit marks the resolution finished ([houseResolvedNotifier]), so the
  /// router can never be left believing a lookup is still in flight. Note that
  /// resolution is NOT reset to `false` at the start: a redundant re-load for
  /// the same session (e.g. an auth token refresh re-emitting) must not put the
  /// user back into the unknown state.
  Future<void> loadUserHouse(String userId) async {
    final generation = ++_resolutionGeneration;

    for (var attempt = 1; attempt <= _maxHouseLoadAttempts; attempt++) {
      try {
        final house = await _remote
            .findHouseByUserId(userId)
            .timeout(_attemptTimeout);
        // The session moved on while this was in flight — its answer belongs to
        // the previous user, not this one.
        if (generation != _resolutionGeneration) return;
        // null is definitive ("no active membership") — no further retry.
        _currentHouseNotifier.value = house;
        _houseResolvedNotifier.value = true;
        return;
      } catch (e) {
        debugPrint(
          '[HouseRepository] loadUserHouse attempt $attempt/$_maxHouseLoadAttempts '
          'failed: $e',
        );
        if (generation != _resolutionGeneration) return;
        if (attempt == _maxHouseLoadAttempts) {
          // Give up for now rather than spin forever; the house stays null so
          // the guard still shows the onboarding screen on a real failure. The
          // resolution is finished either way — "no house we could find" is a
          // definitive answer, not an unresolved one.
          _currentHouseNotifier.value = null;
          _houseResolvedNotifier.value = true;
          return;
        }
        await Future<void>.delayed(_houseLoadRetryDelay);
        // Re-checked at the top of the next attempt, but bail out here too so a
        // clear during the pause cannot start one more read for a dead session.
        if (generation != _resolutionGeneration) return;
      }
    }
  }

  @override
  Future<void> clearCurrentHouse() async {
    // Invalidate any lookup still in flight for the session being ended.
    _resolutionGeneration++;
    _currentHouseNotifier.value = null;
    // Back to "unknown". The next session must resolve for itself before the
    // router may decide where its user belongs; keeping the previous answer
    // here would hand the new session the old one's redirect decision.
    _houseResolvedNotifier.value = false;
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
      // The data layer already recognised the expected rejections and tagged
      // them with a stable code — carry it through so the UI can explain what
      // happened in the user's own language instead of showing this sentence.
      if (e is AppException && e.code != null) {
        throw FirebaseFailure(e.message, code: e.code, arguments: e.arguments);
      }
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
  Stream<List<HouseMemberEntity>> allMembersStream(String houseId) {
    return _remote.allMembersStream(houseId);
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
    _houseResolvedNotifier.dispose();
  }
}
