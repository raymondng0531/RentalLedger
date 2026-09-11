import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_ledger/app/router/auth_guard.dart';
import 'package:rental_ledger/app/router/route_names.dart';
import 'package:rental_ledger/core/constants/app_constants.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/domain/repositories/auth_repository.dart';
import 'package:rental_ledger/features/authentication/presentation/pages/splash_page.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/features/members/data/datasources/house_remote_datasource.dart';
import 'package:rental_ledger/features/members/data/models/house_member_model.dart';
import 'package:rental_ledger/features/members/data/models/house_model.dart';
import 'package:rental_ledger/features/members/data/repositories/house_repository_impl.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';

/// Startup, end to end: the real [SplashPage], the real [AuthGuard], and the
/// real [HouseRepositoryImpl], wired exactly as `AppRouter` wires them.
///
/// The bug this pins down was a startup flash — an already-signed-in member
/// who owns a house saw Create House for as long as their house lookup took,
/// then got bounced to the Dashboard. Two things have to hold for that to be
/// fixed, and only an end-to-end test can show both:
///
///  * while the lookup is out, the router keeps the user on the splash, so
///    no onboarding page is ever built;
///  * when the answer lands, the router re-evaluates and moves them — which
///    only happens because it observes the resolution notifier.
///
/// The routes below record which page the router decided on, so "Create House
/// was never flashed" is asserted as "the Create House page was never built",
/// rather than inferred. Only the splash is a real page: its own 600 ms timer
/// and `context.go` are half of the race, so it would be worthless to stub.

final _userA = UserEntity(
  uid: 'user-a',
  email: 'alice@example.com',
  displayName: 'Alice',
  createdAt: DateTime(2026, 9),
);

final _userB = UserEntity(
  uid: 'user-b',
  email: 'bob@example.com',
  displayName: 'Bob',
  createdAt: DateTime(2026, 9),
);

final _houseA = HouseModel(
  houseId: 'house-a',
  houseName: 'Sunset Villa',
  inviteCode: 'AB12CD34',
  treasurerId: _userA.uid,
  createdAt: DateTime(2026, 9),
);

/// Records what the router built and how often it consulted the redirect — the
/// two facts every startup assertion here is made of.
class _RouteTrace {
  /// Every page build, in order. A route missing from this list was never
  /// shown.
  final List<String> order = <String>[];

  /// Redirect evaluations. A splash that re-arms its 600 ms timer shows up
  /// here as a count that keeps climbing while nothing else is happening.
  int redirects = 0;

  int buildsOf(String route) => order.where((r) => r == route).length;

  void record(String route) => order.add(route);
}

/// The app's no-transition page (see `AppRouter._noTransition`), replicated so
/// the splash route behaves as it does in production: a zero-duration page
/// whose child is a canonical `const` instance. That identity is what keeps a
/// redirect to the location the user is already on from re-creating the
/// splash's State — and so from re-arming its timer.
Page<T> _noTransition<T>(Widget child) {
  return CustomTransitionPage<T>(
    child: child,
    transitionsBuilder:
        (context, animation, secondaryAnimation, child) => child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

/// A stand-in page that records its own build, so the test can see which route
/// the router chose without standing up the real page's data dependencies.
class _Marker extends StatelessWidget {
  const _Marker(this.route, this.trace, {this.child});

  final String route;
  final _RouteTrace trace;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    trace.record(route);
    return child ?? Scaffold(body: Center(child: Text(route)));
  }
}

/// A [HouseRemoteDataSource] whose only working method is
/// [findHouseByUserId] — the one the resolution path uses. Every other member
/// throws, so a test fails loudly if resolution reaches outside its lookup.
class _FakeHouseRemote implements HouseRemoteDataSource {
  _FakeHouseRemote(this._answer);

  /// Called once per lookup attempt with the user being looked up and the
  /// 1-based attempt number. A house resolves the lookup to it, `null` resolves
  /// it as "no active house", and throwing models a failed read.
  final Future<HouseModel?> Function(String userId, int attempt) _answer;

  int _calls = 0;

  @override
  Future<HouseModel?> findHouseByUserId(String userId) =>
      _answer(userId, ++_calls);

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

  Never _unexpected(String method) =>
      throw StateError('Unexpected: $method called during startup.');
}

/// The only auth member the splash reads.
class _FakeAuth implements AuthRepository {
  _FakeAuth(this._notifier);

  final ValueNotifier<UserEntity?> _notifier;

  @override
  ValueNotifier<UserEntity?> get currentUserNotifier => _notifier;

  @override
  UserEntity? get currentUser => _notifier.value;

  @override
  Never noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected: ${invocation.memberName} called.');
}

/// A cold start: the notifiers the router observes, the repository behind them,
/// and the router itself — wired as `AppRouter` wires them.
class _Startup {
  _Startup({
    required Future<HouseModel?> Function(String userId, int attempt) answer,
    required UserEntity? user,
  })  : remote = _FakeHouseRemote(answer),
        auth = ValueNotifier<UserEntity?>(user) {
    houseRepo = HouseRepositoryImpl(remoteDataSource: remote);
    router = GoRouter(
      initialLocation: RouteNames.splash,
      refreshListenable: Listenable.merge([
        auth,
        houseRepo.currentHouseNotifier,
        houseRepo.houseResolvedNotifier,
      ]),
      redirect: (context, state) {
        trace.redirects++;
        return _guard.handleRedirect(
          context,
          state,
          currentUser: auth.value,
          hasHouse: houseRepo.currentHouseNotifier.value != null,
          isHouseResolved: houseRepo.houseResolvedNotifier.value,
        );
      },
      routes: [
        GoRoute(
          path: RouteNames.splash,
          name: RouteNames.splash,
          pageBuilder: (context, state) => _noTransition(
            _Marker(RouteNames.splash, trace, child: const SplashPage()),
          ),
        ),
        GoRoute(
          path: RouteNames.login,
          name: RouteNames.login,
          pageBuilder: (context, state) =>
              _noTransition(_Marker(RouteNames.login, trace)),
        ),
        GoRoute(
          path: RouteNames.createHouse,
          name: RouteNames.createHouse,
          pageBuilder: (context, state) =>
              _noTransition(_Marker(RouteNames.createHouse, trace)),
        ),
        GoRoute(
          path: RouteNames.joinHouse,
          name: RouteNames.joinHouse,
          pageBuilder: (context, state) =>
              _noTransition(_Marker(RouteNames.joinHouse, trace)),
        ),
        GoRoute(
          path: RouteNames.dashboard,
          name: RouteNames.dashboard,
          pageBuilder: (context, state) =>
              _noTransition(_Marker(RouteNames.dashboard, trace)),
        ),
      ],
    );
  }

  static final AuthGuard _guard = AuthGuard();

  final _FakeHouseRemote remote;
  final ValueNotifier<UserEntity?> auth;
  final _RouteTrace trace = _RouteTrace();

  late final HouseRepositoryImpl houseRepo;
  late final GoRouter router;

  /// The app root: the router inside the scope the splash page reads auth from.
  Widget get app => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuth(auth)),
        ],
        child: MaterialApp.router(routerConfig: router),
      );

  /// What `houseCoordinatorProvider` does when a session appears.
  Future<void> lookUpHouse(String userId) => houseRepo.loadUserHouse(userId);
}

/// The user is on the app's loading state, and no page that depends on the
/// house has been shown.
void _expectHeldOnSplash(_RouteTrace trace) {
  expect(
    trace.buildsOf(RouteNames.splash),
    greaterThan(0),
    reason: 'the splash is the loading state — it must stay up',
  );
  expect(
    trace.buildsOf(RouteNames.createHouse),
    0,
    reason: 'Create House must never be flashed while the answer is unknown',
  );
  expect(
    trace.buildsOf(RouteNames.joinHouse),
    0,
    reason: 'Join House must never be flashed while the answer is unknown',
  );
  expect(
    trace.buildsOf(RouteNames.dashboard),
    0,
    reason: 'the Dashboard must not open before the house state is ready',
  );
}

void main() {
  group('Startup — the house lookup is still out', () {
    testWidgets('holds a returning member on the splash, never on Create House',
        (tester) async {
      final pending = Completer<HouseModel?>();
      final startup = _Startup(answer: (_, __) => pending.future, user: _userA);

      await tester.pumpWidget(startup.app);
      final load = startup.lookUpHouse(_userA.uid);
      await tester.pump();

      _expectHeldOnSplash(startup.trace);

      // The splash's own 600 ms timer fires while the lookup is still out. It
      // navigates to the Dashboard, and the guard sends it straight back to the
      // splash — this is the moment that used to land on Create House.
      final redirectsBeforeSplashTimer = startup.trace.redirects;
      await tester.pump(AppDurations.splash);
      expect(
        startup.trace.redirects,
        greaterThan(redirectsBeforeSplashTimer),
        reason: 'the splash timer must have been exercised for this to mean '
            'anything',
      );
      _expectHeldOnSplash(startup.trace);
      expect(find.byType(SplashPage), findsOneWidget);

      // Now give a re-arming splash every chance to loop: six seconds is ten
      // splash timers. Nothing moves on its own — only the resolution may.
      final redirectsWhileHeld = startup.trace.redirects;
      await tester.pump(const Duration(seconds: 6));
      expect(
        startup.trace.redirects,
        lessThanOrEqualTo(redirectsWhileHeld + 2),
        reason: 'a re-armed splash timer would add a pair of redirects every '
            '600 ms — the user must not be in a redirect loop',
      );
      _expectHeldOnSplash(startup.trace);

      // The house arrives.
      pending.complete(_houseA);
      await tester.pump();
      await tester.pump();

      expect(
        startup.trace.buildsOf(RouteNames.dashboard),
        greaterThan(0),
        reason: 'resolution must reach the router and open the Dashboard',
      );
      expect(
        startup.trace.buildsOf(RouteNames.createHouse),
        0,
        reason: 'a member who has a house must never see Create House',
      );

      await load;
    });

    testWidgets('holds a first-time member too, and releases them into Create House',
        (tester) async {
      final pending = Completer<HouseModel?>();
      final startup = _Startup(answer: (_, __) => pending.future, user: _userB);

      await tester.pumpWidget(startup.app);
      final load = startup.lookUpHouse(_userB.uid);
      await tester.pump(AppDurations.splash);

      // Onboarding must not open on a guess either — and it must not be held
      // any longer than the answer takes.
      _expectHeldOnSplash(startup.trace);

      pending.complete(null);
      await tester.pump();
      await tester.pump();

      expect(
        startup.trace.buildsOf(RouteNames.createHouse),
        greaterThan(0),
        reason: 'a definitive "no house" must release the user into onboarding',
      );

      await load;
    });
  });

  group('Startup — the lookup has already finished', () {
    testWidgets('a member with a house goes straight to the Dashboard',
        (tester) async {
      final startup = _Startup(
        answer: (_, __) => Future.value(_houseA),
        user: _userA,
      );

      // Resolution completed before the first frame, as it does when the
      // cached session restores faster than the router builds.
      await startup.lookUpHouse(_userA.uid);

      await tester.pumpWidget(startup.app);
      await tester.pump();

      expect(startup.trace.buildsOf(RouteNames.dashboard), greaterThan(0));
      expect(
        startup.trace.buildsOf(RouteNames.splash),
        0,
        reason: 'there is nothing to wait for — the startup state is known',
      );
      expect(startup.trace.buildsOf(RouteNames.createHouse), 0);
    });
  });

  group('Startup — signed out', () {
    testWidgets('a visitor reaches Login and no house state disturbs it',
        (tester) async {
      final startup = _Startup(
        answer: (_, __) => Future.value(_houseA),
        user: null,
      );

      // A house left behind by a previous session, and a resolution flag left
      // behind with it. Neither may pull a signed-out visitor anywhere.
      startup.houseRepo.currentHouseNotifier.value = _houseA;

      await tester.pumpWidget(startup.app);
      await tester.pump(AppDurations.splash);
      await tester.pump(const Duration(milliseconds: 1));

      expect(
        startup.trace.buildsOf(RouteNames.login),
        greaterThan(0),
        reason: 'signed-out startup is unchanged: the Login page',
      );
      expect(startup.trace.buildsOf(RouteNames.createHouse), 0);
      expect(startup.trace.buildsOf(RouteNames.dashboard), 0);

      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('Startup — switching accounts', () {
    testWidgets('a new session resolves its own house, not the last one',
        (tester) async {
      final startup = _Startup(
        answer: (userId, _) => Future.value(userId == _userB.uid ? null : _houseA),
        user: _userA,
      );

      // user A signs in with a house.
      await tester.pumpWidget(startup.app);
      await startup.lookUpHouse(_userA.uid);
      await tester.pump();
      await tester.pump();
      expect(startup.trace.buildsOf(RouteNames.dashboard), greaterThan(0));

      // user A logs out — `houseCoordinatorProvider` clears the house and the
      // resolution state with it.
      startup.auth.value = null;
      await startup.houseRepo.clearCurrentHouse();
      await tester.pump();
      expect(startup.trace.buildsOf(RouteNames.login), greaterThan(0));

      // user B signs in. Their lookup has not run yet, so the session knows
      // nothing — least of all that user A's house is theirs.
      startup.auth.value = _userB;
      await tester.pump();

      expect(
        startup.trace.buildsOf(RouteNames.createHouse),
        0,
        reason: 'user B must not be decided on before their own lookup runs',
      );
      expect(
        startup.trace.buildsOf(RouteNames.dashboard),
        1,
        reason: "the Dashboard must not reopen on user A's house",
      );

      // user B genuinely has no house, and now the app knows it.
      await startup.lookUpHouse(_userB.uid);
      await tester.pump();
      await tester.pump();

      expect(startup.trace.buildsOf(RouteNames.createHouse), greaterThan(0));
      expect(
        startup.trace.buildsOf(RouteNames.dashboard),
        1,
        reason: 'no Dashboard for a session with no house',
      );

      await tester.pump(const Duration(seconds: 1));
    });
  });
}
