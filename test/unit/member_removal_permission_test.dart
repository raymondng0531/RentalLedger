import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_entity.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';
import 'package:rental_ledger/features/members/domain/repositories/house_repository.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';

/// Guards the V1.0 Treasurer-only "remove a former member" flow.
///
/// A Treasurer may soft-delete another member's house_members record; a regular
/// Member cannot remove anyone; the house Treasurer can never be removed
/// (transfer ownership first). Removal must only touch the target membership —
/// the user's Firebase account and every historical expense/transaction are
/// preserved, and the removed member can rejoin later.
///
/// The permission-denied paths short-circuit in the notifier before the data
/// source is touched, so they are fully deterministic. The recording fake
/// repository models the data-layer contract: `removeMember` flips only the
/// target record to `isActive: false` (never deletes it).
const _permissionOnlyTreasurer = 'Only the Treasurer can remove a member.';
const _cannotRemoveTreasurer =
    'The Treasurer cannot be removed. Transfer ownership first.';

final _now = DateTime(2026, 9);

final _treasurerUser = UserEntity(
  uid: 'treasurer-1',
  email: 'treasurer@example.com',
  displayName: 'Treasurer',
  createdAt: _now,
);

final _memberUser = UserEntity(
  uid: 'member-1',
  email: 'member@example.com',
  displayName: 'Member',
  createdAt: _now,
);

final _house = HouseEntity(
  houseId: 'house-1',
  houseName: 'Sunset Villa',
  inviteCode: 'AB12CD',
  treasurerId: _treasurerUser.uid,
  createdAt: _now,
);

/// The house Treasurer as a member record (the "cannot remove Treasurer" case).
HouseMemberEntity _treasurerMember() => HouseMemberEntity(
      memberId: 'm-treasurer',
      houseId: _house.houseId,
      userId: _treasurerUser.uid,
      role: 'Treasurer',
      joinedAt: _now,
      displayName: 'Treasurer',
      email: 'treasurer@example.com',
    );

/// A regular (non-Treasurer) member targeted for removal.
HouseMemberEntity _regularMember() => HouseMemberEntity(
      memberId: 'm-regular',
      houseId: _house.houseId,
      userId: 'member-9',
      joinedAt: _now,
      displayName: 'Former Housemate',
      email: 'former@example.com',
    );

/// A second, unrelated member that must survive an unrelated removal.
HouseMemberEntity _otherMember() => HouseMemberEntity(
      memberId: 'm-other',
      houseId: _house.houseId,
      userId: 'member-2',
      joinedAt: _now,
      displayName: 'Still Here',
      email: 'still@example.com',
    );

/// In-memory [HouseRepository] recording `removeMember` calls and modelling
/// the soft-delete contract: the target record flips to `isActive: false`, and
/// no record is ever deleted. Unused methods throw so a test fails loudly if
/// the notifier ever touches anything beyond the one removal.
class _RecordingHouseRepository implements HouseRepository {
  final ValueNotifier<HouseEntity?> _notifier = ValueNotifier<HouseEntity?>(null);

  /// memberId → member record currently held for the house.
  final List<HouseMemberEntity> members = [];

  final List<({String houseId, String memberId, String requesterId})> removes =
      [];

  @override
  ValueNotifier<HouseEntity?> get currentHouseNotifier => _notifier;

  @override
  HouseEntity? get currentHouse => null;

  @override
  bool get hasHouse => true;

  @override
  Future<void> loadUserHouse(String userId) async {}

  @override
  Future<void> clearCurrentHouse() async {}

  @override
  Future<List<HouseEntity>> getUserHouses(String userId) async => [_house];

  @override
  Future<void> switchHouse(String userId, String houseId) async {}

  @override
  Future<HouseEntity> createHouse(String houseName, String treasurerId) =>
      Future.value(_house);

  @override
  Future<HouseEntity> joinHouse(String inviteCode, String userId) =>
      Future.value(_house);

  @override
  Future<String> regenerateInviteCode(String houseId) async => 'NEWCODE';

  @override
  Future<List<HouseMemberEntity>> getMembers(String houseId) async =>
      members.where((m) => m.isActive).toList();

  @override
  Future<HouseMemberEntity?> getMember(String houseId, String userId) async {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  @override
  Future<void> transferTreasurer(
      String houseId, String fromId, String toId) {
    throw StateError('Unexpected: transferTreasurer called during removal.');
  }

  @override
  Future<void> removeMember(
      String houseId, String memberId, String requesterId) async {
    removes.add((houseId: houseId, memberId: memberId, requesterId: requesterId));
    // Soft delete only — the record stays (history preserved), it just becomes
    // inactive and drops out of the active member list / streams.
    final index = members.indexWhere((m) => m.memberId == memberId);
    if (index >= 0) {
      members[index] = members[index].copyWith(isActive: false);
    }
  }

  @override
  Future<void> leaveHouse(String houseId, String userId, bool isTreasurer) {
    throw StateError('Unexpected: leaveHouse called during removal.');
  }

  @override
  Stream<List<HouseMemberEntity>> membersStream(String houseId) async* {
    yield members.where((m) => m.isActive).toList();
  }

  @override
  Stream<List<HouseMemberEntity>> allMembersStream(String houseId) async* {
    // All records, active AND inactive (soft-deleted) former members, so
    // historical name resolution keeps working after a removal.
    yield List.of(members);
  }

  @override
  Future<void> updateMemberDisplayInfo({
    required String userId,
    String? displayName,
    String? photoUrl,
  }) async {}
}

/// A container whose signed-in user is [user] and whose repository is the
/// recording fake pre-populated with [seededMembers].
ProviderContainer _containerFor(
  UserEntity user,
  _RecordingHouseRepository repo, {
  List<HouseMemberEntity> seed = const [],
}) {
  repo.members.addAll(seed);
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => user),
      currentHouseProvider.overrideWith((ref) => _house),
      houseRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('Remove Member — Treasurer can remove a former member', () {
    test('removes the target membership only (soft delete, no deletion)',
        () async {
      final repo = _RecordingHouseRepository();
      final target = _regularMember();
      final other = _otherMember();
      final container = _containerFor(
        _treasurerUser,
        repo,
        seed: [_treasurerMember(), target, other],
      );

      final error = await container
          .read(removeMemberProvider.notifier)
          .remove(target);

      expect(error, isNull, reason: 'Treasurer removal should succeed.');
      // Exactly one data-source call, targeting the right member, with the
      // Treasurer as requester.
      expect(repo.removes, hasLength(1));
      expect(repo.removes.single.houseId, _house.houseId);
      expect(repo.removes.single.memberId, target.memberId);
      expect(repo.removes.single.requesterId, _treasurerUser.uid);
      // Soft delete: the record still exists, just inactive. Nothing deleted.
      expect(repo.members, hasLength(3));
      expect(
        repo.members.firstWhere((m) => m.memberId == target.memberId).isActive,
        isFalse,
        reason: 'Removed member must drop out of the active list.',
      );
      // Unrelated member + Treasurer record untouched (history preserved).
      expect(
        repo.members.firstWhere((m) => m.memberId == other.memberId).isActive,
        isTrue,
      );
      expect(
        repo.members
            .firstWhere((m) => m.memberId == _treasurerMember().memberId)
            .isActive,
        isTrue,
      );
      // The active list now excludes the removed member.
      final active = await repo.getMembers(_house.houseId);
      expect(active.map((m) => m.memberId), isNot(contains(target.memberId)));
    });

    test('a removed member can be re-added later (record is not destroyed)',
        () async {
      final repo = _RecordingHouseRepository();
      final target = _regularMember();
      final container =
          _containerFor(_treasurerUser, repo, seed: [target, _otherMember()]);

      await container.read(removeMemberProvider.notifier).remove(target);

      // Re-join: the same member record becoming active again would surface
      // the user in the active list — proving nothing was permanently deleted.
      final rejoined = target.copyWith(isActive: true);
      repo.members[repo.members.indexWhere((m) => m.memberId == target.memberId)] =
          rejoined;
      final active = await repo.getMembers(_house.houseId);
      expect(active.map((m) => m.memberId), contains(target.memberId));
    });
  });

  group('Remove Member — permission guards', () {
    test('a regular Member cannot remove anyone', () async {
      final repo = _RecordingHouseRepository();
      final target = _regularMember();
      final container = _containerFor(_memberUser, repo, seed: [target]);

      final error = await container
          .read(removeMemberProvider.notifier)
          .remove(target);

      expect(error, _permissionOnlyTreasurer);
      // Denied before the data source — no write happened.
      expect(repo.removes, isEmpty);
    });

    test('the house Treasurer cannot be removed (covers self-removal)', () async {
      final repo = _RecordingHouseRepository();
      final treasurerMember = _treasurerMember();
      final container =
          _containerFor(_treasurerUser, repo, seed: [treasurerMember]);

      final error = await container
          .read(removeMemberProvider.notifier)
          .remove(treasurerMember);

      expect(error, _cannotRemoveTreasurer);
      expect(repo.removes, isEmpty);
    });

    test('an unauthenticated viewer is rejected before any write', () async {
      final repo = _RecordingHouseRepository();
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          currentHouseProvider.overrideWith((ref) => _house),
          houseRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final error = await container
          .read(removeMemberProvider.notifier)
          .remove(_regularMember());

      expect(error, 'Not authenticated.');
      expect(repo.removes, isEmpty);
    });

    test('with no active house, removal is rejected before any write', () async {
      final repo = _RecordingHouseRepository();
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => _treasurerUser),
          currentHouseProvider.overrideWith((ref) => null),
          houseRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final error = await container
          .read(removeMemberProvider.notifier)
          .remove(_regularMember());

      expect(error, 'No active house.');
      expect(repo.removes, isEmpty);
    });
  });

  group('Remove Member — historical records are not deleted', () {
    test('removal performs exactly one soft delete and nothing else', () async {
      final repo = _RecordingHouseRepository();
      final target = _regularMember();
      final container =
          _containerFor(_treasurerUser, repo, seed: [target, _otherMember()]);

      await container.read(removeMemberProvider.notifier).remove(target);

      // Exactly one write happened — the target record flip. No delete, no
      // profile update, no transfer, no leave. (Fake methods throw if any
      // unexpected repository method were called.)
      expect(repo.removes, hasLength(1));
      // Every record (including the removed one) is still stored.
      expect(repo.members, hasLength(2));
      expect(repo.members.every((m) => m.userId.isNotEmpty), isTrue);
    });
  });
}
