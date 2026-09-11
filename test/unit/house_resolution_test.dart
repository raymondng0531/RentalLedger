import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/errors/exceptions.dart';
import 'package:rental_ledger/features/members/data/datasources/house_remote_datasource.dart';
import 'package:rental_ledger/features/members/data/models/house_member_model.dart';
import 'package:rental_ledger/features/members/data/models/house_model.dart';
import 'package:rental_ledger/features/members/data/repositories/house_repository_impl.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';

/// Guards the third state the router needs: whether a session's house lookup
/// has FINISHED.
///
/// `currentHouse == null` cannot express this. It means both "we have not
/// looked yet" and "we looked, and this user has no house" — and on a cold
/// start the session is restored before the lookup completes, so a member who
/// does have a house briefly looked house-less. The router sent them to Create
/// House on that. [HouseRepositoryImpl.houseResolvedNotifier] separates the two
/// states, and these tests pin down every way it is allowed to move:
///
///  * it starts `false` — a fresh app has not looked anything up
///  * every exit from a lookup ends it `true`: a house, a definitive no-house,
///    and a lookup that failed every attempt
///  * `clearCurrentHouse` (logout / account switch) returns it to `false`, so
///    the next session must resolve for itself
///  * a late answer from an ended session can never publish a house or a
///    resolved flag into the session that replaced it
///
/// `testWidgets` is used as a clock, not for its widget tree: it runs the body
/// in a fake-async zone, so the repository's real retry back-off (600 ms, and
/// the per-attempt ceiling) elapses instantly under `tester.pump(duration)`
/// instead of making these tests wait seconds of wall time.

final _houseA = HouseModel(
  houseId: 'house-a',
  houseName: 'Sunset Villa',
  inviteCode: 'AB12CD34',
  treasurerId: 'user-a',
  createdAt: DateTime(2026, 9),
);

final _houseB = HouseModel(
  houseId: 'house-b',
  houseName: 'Lakeside',
  inviteCode: 'EF56GH78',
  treasurerId: 'user-b',
  createdAt: DateTime(2026, 9),
);

/// One pump of the retry back-off — long enough to release the repository's
/// pause between attempts.
const _retryStep = Duration(milliseconds: 600);

/// A [HouseRemoteDataSource] whose only working method is
/// [findHouseByUserId] — the one the resolution path uses. Every other member
/// throws, so a test fails loudly if resolution ever reaches outside its
/// lookup.
class _FakeHouseRemote implements HouseRemoteDataSource {
  _FakeHouseRemote(this._answer);

  /// Called once per lookup attempt with the user being looked up and the
  /// 1-based attempt number. Returning a house resolves the lookup to it,
  /// returning `null` resolves it as "no active house", and throwing models a
  /// failed read.
  final Future<HouseModel?> Function(String userId, int attempt) _answer;

  int findCalls = 0;

  @override
  Future<HouseModel?> findHouseByUserId(String userId) {
    findCalls++;
    return _answer(userId, findCalls);
  }

  // ── Not part of the resolution path ──

  @override
  Future<HouseModel?> getHouse(String houseId) => _unexpected('getHouse');

  @override
  Future<void> setActiveHouse(String userId, String houseId) =>
      _unexpected('setActiveHouse');

  @override
  Future<List<HouseModel>> getUserHouses(String userId) =>
      _unexpected('getUserHouses');

  @override
  Future<HouseModel> createHouse(String houseName, String treasurerId) =>
      _unexpected('createHouse');

  @override
  Future<HouseModel> joinHouse(String inviteCode, String userId) =>
      _unexpected('joinHouse');

  @override
  Future<String> regenerateInviteCode(String houseId) =>
      _unexpected('regenerateInviteCode');

  @override
  Stream<List<HouseMemberEntity>> membersStream(String houseId) =>
      _unexpected('membersStream');

  @override
  Stream<List<HouseMemberEntity>> allMembersStream(String houseId) =>
      _unexpected('allMembersStream');

  @override
  Future<List<HouseMemberEntity>> getMembers(String houseId) =>
      _unexpected('getMembers');

  @override
  Future<void> updateMemberDisplayInfo({
    required String userId,
    String? displayName,
    String? photoUrl,
  }) =>
      _unexpected('updateMemberDisplayInfo');

  @override
  Future<HouseMemberModel?> getMember(String houseId, String userId) =>
      _unexpected('getMember');

  @override
  Future<void> transferTreasurer(
    String houseId,
    String currentTreasurerId,
    String newTreasurerId,
  ) =>
      _unexpected('transferTreasurer');

  @override
  Future<void> removeMember(
    String houseId,
    String memberId,
    String requesterId,
  ) =>
      _unexpected('removeMember');

  @override
  Future<void> leaveHouse(String houseId, String userId) =>
      _unexpected('leaveHouse');

  Never _unexpected(String method) => throw StateError(
        'Unexpected: $method called during house resolution.',
      );
}

/// Records every value [notifier] publishes, so a test can assert not just the
/// end state but that the router was actually told about it — a flag nothing
/// observes would leave the user parked on the splash.
List<bool> _record(ValueNotifier<bool> notifier) {
  final seen = <bool>[];
  notifier.addListener(() => seen.add(notifier.value));
  return seen;
}

/// Drains microtasks without moving the clock — enough to finish a lookup whose
/// read answers straight away, and deliberately not enough to release a retry
/// back-off. A lookup that needs a timer here has delayed a first-time user.
Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

/// Advances the fake clock until [load] finishes, releasing the retry back-off
/// as needed.
Future<void> _runLookup(WidgetTester tester, Future<void> load) async {
  var finished = false;
  unawaited(load.then((_) => finished = true));
  for (var pump = 0; pump < 40 && !finished; pump++) {
    await tester.pump(_retryStep);
  }
  expect(
    finished,
    isTrue,
    reason: 'every lookup must end definitively — the router holds the user '
        'on the splash until the resolution state settles',
  );
}

void main() {
  group('House resolution — before the lookup runs', () {
    testWidgets('a fresh repository reports the house as unresolved',
        (tester) async {
      final remote = _FakeHouseRemote((_, __) => Future.value(_houseA));
      final repo = HouseRepositoryImpl(remoteDataSource: remote);

      // A cold start knows nothing yet. Reporting "no house" here is exactly
      // what used to send a returning member to Create House.
      expect(repo.isHouseResolved, isFalse);
      expect(repo.houseResolvedNotifier.value, isFalse);
      expect(repo.currentHouse, isNull);
      expect(repo.hasHouse, isFalse);
      expect(remote.findCalls, 0, reason: 'nothing has been looked up yet');
    });
  });

  group('House resolution — a house was found', () {
    testWidgets('publishes the house and marks the lookup resolved',
        (tester) async {
      final remote = _FakeHouseRemote((_, __) => Future.value(_houseA));
      final repo = HouseRepositoryImpl(remoteDataSource: remote);
      final seen = _record(repo.houseResolvedNotifier);

      await _runLookup(tester, repo.loadUserHouse('user-a'));

      expect(repo.currentHouse, _houseA);
      expect(repo.hasHouse, isTrue);
      expect(repo.isHouseResolved, isTrue);
      expect(remote.findCalls, 1, reason: 'a clean read must not be retried');
      // Exactly one transition — the router re-evaluates redirects on every
      // notification, so a flag that flickers would flicker the route.
      expect(seen, [true]);
    });
  });

  group('House resolution — the user has no house', () {
    testWidgets('resolves immediately, without delaying onboarding',
        (tester) async {
      final remote = _FakeHouseRemote((_, __) => Future<HouseModel?>.value());
      final repo = HouseRepositoryImpl(remoteDataSource: remote);
      final seen = _record(repo.houseResolvedNotifier);

      final load = repo.loadUserHouse('user-new');
      await _flush(tester);

      // "No active membership" is a definitive answer, not a failure: it must
      // leave the user no worse off than before the resolution state existed,
      // so it costs no retry pause and no second read.
      expect(repo.currentHouse, isNull);
      expect(repo.isHouseResolved, isTrue);
      expect(remote.findCalls, 1);
      expect(seen, [true]);

      await load;
    });
  });

  group('House resolution — a read failed', () {
    testWidgets('a transient failure is retried, then resolved', (tester) async {
      final remote = _FakeHouseRemote((_, attempt) {
        if (attempt == 1) {
          return Future<HouseModel?>.error(
            const AppFirebaseException('Failed to load your house.'),
          );
        }
        return Future.value(_houseA);
      });
      final repo = HouseRepositoryImpl(remoteDataSource: remote);

      await _runLookup(tester, repo.loadUserHouse('user-a'));

      expect(remote.findCalls, 2);
      expect(repo.currentHouse, _houseA);
      expect(repo.isHouseResolved, isTrue);
    });

    testWidgets('exhausting the retries still resolves, as "no house"',
        (tester) async {
      final remote = _FakeHouseRemote(
        (_, __) => Future<HouseModel?>.error(
          const AppFirebaseException('Failed to load your house.'),
        ),
      );
      final repo = HouseRepositoryImpl(remoteDataSource: remote);
      final seen = _record(repo.houseResolvedNotifier);

      await _runLookup(tester, repo.loadUserHouse('user-a'));

      // The existing bounded retry (4 attempts) is unchanged…
      expect(remote.findCalls, 4);
      // …and it ends in a definitive answer rather than a permanent "still
      // resolving": the router can never be left believing a lookup is in
      // flight, which would strand the user on the splash with no way forward.
      expect(repo.isHouseResolved, isTrue);
      expect(repo.currentHouse, isNull);
      expect(seen, [true]);
    });

    testWidgets('a read that never answers cannot pend forever', (tester) async {
      // Each attempt hangs: without the per-attempt ceiling this loop — and so
      // the resolution state — would never complete.
      final remote = _FakeHouseRemote((_, __) => Completer<HouseModel?>().future);
      final repo = HouseRepositoryImpl(
        remoteDataSource: remote,
        attemptTimeout: const Duration(milliseconds: 50),
      );

      await _runLookup(tester, repo.loadUserHouse('user-a'));

      expect(remote.findCalls, 4, reason: 'a hang is retried like any failure');
      expect(repo.isHouseResolved, isTrue);
      expect(repo.currentHouse, isNull);
    });
  });

  group('House resolution — a redundant re-load', () {
    testWidgets('does not put a resolved session back into the unknown',
        (tester) async {
      final pending = Completer<HouseModel?>();
      final remote = _FakeHouseRemote(
        (_, attempt) => attempt == 1 ? Future.value(_houseA) : pending.future,
      );
      final repo = HouseRepositoryImpl(remoteDataSource: remote);
      final seen = _record(repo.houseResolvedNotifier);

      await _runLookup(tester, repo.loadUserHouse('user-a'));

      // A token refresh re-emitting the same user re-runs the lookup. The
      // session already has its answer, so the router must not be told the
      // house went back to unknown — that would flash the splash at someone
      // who is sitting on the Dashboard.
      final reload = repo.loadUserHouse('user-a');
      await _flush(tester);
      expect(repo.isHouseResolved, isTrue);
      expect(repo.currentHouse, _houseA);

      pending.complete(_houseA);
      await _runLookup(tester, reload);

      expect(repo.isHouseResolved, isTrue);
      expect(repo.currentHouse, _houseA);
      expect(seen, [true], reason: 'the flag never went back to false');
    });
  });

  group('House resolution — logout and account switching', () {
    testWidgets('clearing the house returns the session to unresolved',
        (tester) async {
      final remote = _FakeHouseRemote((_, __) => Future.value(_houseA));
      final repo = HouseRepositoryImpl(remoteDataSource: remote);
      final seen = _record(repo.houseResolvedNotifier);

      await _runLookup(tester, repo.loadUserHouse('user-a'));
      await repo.clearCurrentHouse();

      // Signed out: no house, and nothing known about one. Keeping the flag
      // true here would let the next session inherit this redirect decision.
      expect(repo.currentHouse, isNull);
      expect(repo.isHouseResolved, isFalse);
      expect(seen, [true, false]);
    });

    testWidgets('a late answer cannot resolve the session that replaced it',
        (tester) async {
      final inFlight = Completer<HouseModel?>();
      final remote = _FakeHouseRemote(
        (userId, _) => userId == 'user-a'
            ? inFlight.future
            : Future.value(_houseB),
      );
      final repo = HouseRepositoryImpl(remoteDataSource: remote);

      final loadA = repo.loadUserHouse('user-a');
      await _flush(tester);
      expect(repo.isHouseResolved, isFalse);

      // user-a signs out mid-lookup, then user-b signs in.
      await repo.clearCurrentHouse();
      await _runLookup(tester, repo.loadUserHouse('user-b'));
      expect(repo.currentHouse, _houseB);
      expect(repo.isHouseResolved, isTrue);

      // user-a's read finally answers. It belongs to a session that is over.
      inFlight.complete(_houseA);
      await _runLookup(tester, loadA);

      expect(
        repo.currentHouse,
        _houseB,
        reason: "a stale answer must not overwrite the new session's house",
      );
      expect(repo.isHouseResolved, isTrue);
    });

    testWidgets('a cleared session discards an answer already in flight',
        (tester) async {
      final inFlight = Completer<HouseModel?>();
      final remote = _FakeHouseRemote((_, __) => inFlight.future);
      final repo = HouseRepositoryImpl(remoteDataSource: remote);

      final load = repo.loadUserHouse('user-a');
      await _flush(tester);

      await repo.clearCurrentHouse();
      inFlight.complete(_houseA);
      await _runLookup(tester, load);

      // The lookup was for a session that has ended. It must not publish a
      // house — nor mark the (now signed-out) session resolved, which would
      // hand the router an answer for a user who is no longer there.
      expect(repo.currentHouse, isNull);
      expect(repo.isHouseResolved, isFalse);
    });
  });
}
