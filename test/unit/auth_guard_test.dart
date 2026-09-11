import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_ledger/app/router/auth_guard.dart';
import 'package:rental_ledger/app/router/route_names.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';

/// Guards the one decision the whole startup flow hangs on: where a signed-in
/// user belongs when the app does not yet know whether they have a house.
///
/// The guard's inputs describe three distinct states, and every one of them is
/// pinned down here:
///
///  * house lookup not finished → hold on the splash, never Create House
///  * finished, house found     → Dashboard
///  * finished, no house        → Create House (the existing onboarding)
///
/// The first state is the one that used to be missing. `hasHouse == false`
/// could not tell "not looked up yet" apart from "looked up, no house", so a
/// returning member was sent to Create House for as long as their lookup took
/// and then bounced on to the Dashboard.
///
/// [GoRouterState] is built for real (off a bare router) rather than stubbed,
/// so these run against the same object GoRouter hands the guard in `redirect`.

final _user = UserEntity(
  uid: 'u-member',
  email: 'alice@example.com',
  displayName: 'Alice',
  createdAt: DateTime(2026, 9),
);

final _guard = AuthGuard();

/// The guard reads only [GoRouterState.uri]; a minimal router is enough to
/// produce real state objects.
final _router = GoRouter(
  routes: [
    GoRoute(
      path: RouteNames.splash,
      builder: (_, __) => const SizedBox.shrink(),
    ),
  ],
);

GoRouterState _stateAt(String location) {
  final uri = Uri.parse(location);
  return GoRouterState(
    _router.configuration,
    uri: uri,
    matchedLocation: uri.path,
    fullPath: uri.path,
    pathParameters: const {},
    pageKey: ValueKey<String>(location),
  );
}

/// A real element context. The guard never touches it — it takes one only
/// because GoRouter's `redirect` callback supplies one.
Future<BuildContext> _context(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  return tester.element(find.byType(SizedBox));
}

/// Runs the guard for one startup state.
///
/// Every input is supplied explicitly at each call site: these tests are the
/// decision matrix, so which state is being tested has to be legible where it
/// is read rather than implied by the guard's defaults. (The defaults get their
/// own group at the bottom.)
String? _redirect(
  BuildContext context,
  String location, {
  UserEntity? user,
  required bool hasHouse,
  required bool resolved,
}) {
  return _guard.handleRedirect(
    context,
    _stateAt(location),
    currentUser: user,
    hasHouse: hasHouse,
    isHouseResolved: resolved,
  );
}

void main() {
  group('AuthGuard — house lookup not finished', () {
    testWidgets('does not send a protected page to Create House',
        (tester) async {
      final context = await _context(tester);

      // The SU-1 regression itself: this is the redirect that flashed
      // "Create House" at a member who does have a house.
      expect(
        _redirect(context, RouteNames.dashboard,
            user: _user, hasHouse: false, resolved: false),
        RouteNames.splash,
      );
    });

    testWidgets('holds on the splash instead of bouncing off it',
        (tester) async {
      final context = await _context(tester);

      // Staying put on the splash is what keeps the hold from fighting the
      // auth-page rule below it (splash → Dashboard → splash → …).
      expect(
        _redirect(context, RouteNames.splash,
            user: _user, hasHouse: false, resolved: false),
        isNull,
      );
    });

    testWidgets('holds an onboarding page rather than showing it early',
        (tester) async {
      final context = await _context(tester);

      // Create House/Join must not be reachable before the answer is known:
      // a house-owning member landing there could create a second house.
      for (final location in [RouteNames.createHouse, RouteNames.joinHouse]) {
        expect(
          _redirect(context, location,
              user: _user, hasHouse: false, resolved: false),
          RouteNames.splash,
          reason: '$location must not open before the house state is known',
        );
      }
    });

    testWidgets('holds a signed-in user off the Login page', (tester) async {
      final context = await _context(tester);

      expect(
        _redirect(context, RouteNames.login,
            user: _user, hasHouse: false, resolved: false),
        RouteNames.splash,
      );
    });

    testWidgets('leaves the password-reset deep link reachable', (tester) async {
      final context = await _context(tester);

      // The reset link is opened from an email with its action code in the
      // query string, and is valid signed-in or out — it must never be held,
      // resolved or not.
      expect(
        _redirect(
          context,
          '${RouteNames.resetPassword}?mode=resetPassword&oobCode=abc',
          user: _user,
          hasHouse: false,
          resolved: false,
        ),
        isNull,
      );
    });

    testWidgets('never holds a user whose house is already known',
        (tester) async {
      final context = await _context(tester);

      // Resolution publishes the house a moment before it marks itself done.
      // A known house is a sufficient answer, so that gap must not bounce the
      // user anywhere.
      expect(
        _redirect(context, RouteNames.dashboard,
            user: _user, hasHouse: true, resolved: false),
        isNull,
      );
    });
  });

  group('AuthGuard — house lookup finished', () {
    testWidgets('with a house, an auth page goes to the Dashboard',
        (tester) async {
      final context = await _context(tester);

      expect(
        _redirect(context, RouteNames.login,
            user: _user, hasHouse: true, resolved: true),
        RouteNames.dashboard,
      );
    });

    testWidgets('with a house, onboarding goes to the Dashboard',
        (tester) async {
      final context = await _context(tester);

      expect(
        _redirect(context, RouteNames.createHouse,
            user: _user, hasHouse: true, resolved: true),
        RouteNames.dashboard,
      );
    });

    testWidgets('with a house, a protected page is left alone', (tester) async {
      final context = await _context(tester);

      expect(
        _redirect(context, RouteNames.dashboard,
            user: _user, hasHouse: true, resolved: true),
        isNull,
      );
    });

    testWidgets('with no house, a protected page goes to Create House',
        (tester) async {
      final context = await _context(tester);

      // The first-time user's path — the behaviour that must survive the fix.
      expect(
        _redirect(context, RouteNames.dashboard,
            user: _user, hasHouse: false, resolved: true),
        RouteNames.createHouse,
      );
    });

    testWidgets('with no house, Create House and Join are reachable',
        (tester) async {
      final context = await _context(tester);

      // First-time onboarding must not be able to bounce off its own pages —
      // including the Home-tab link that pushes Create House from the
      // Dashboard's empty state.
      for (final location in [RouteNames.createHouse, RouteNames.joinHouse]) {
        expect(
          _redirect(context, location,
              user: _user, hasHouse: false, resolved: true),
          isNull,
          reason: '$location must be reachable once resolution says "no house"',
        );
      }
    });
  });

  group('AuthGuard — signed out', () {
    testWidgets('a protected page goes to Login', (tester) async {
      final context = await _context(tester);

      expect(
        _redirect(context, RouteNames.dashboard,
            hasHouse: false, resolved: true),
        RouteNames.login,
      );
    });

    testWidgets('auth pages are left alone', (tester) async {
      final context = await _context(tester);

      for (final location in [RouteNames.login, RouteNames.register]) {
        expect(
          _redirect(context, location, hasHouse: false, resolved: true),
          isNull,
        );
      }
    });

    testWidgets('an unfinished lookup never holds a signed-out user',
        (tester) async {
      final context = await _context(tester);

      // Resolution state describes a session's house, so with no session it
      // must have no say at all — a signed-out user still reaches Login, and
      // is never parked on the splash.
      expect(
        _redirect(context, RouteNames.dashboard,
            hasHouse: false, resolved: false),
        RouteNames.login,
      );
      expect(
        _redirect(context, RouteNames.login,
            hasHouse: false, resolved: false),
        isNull,
      );
    });

    testWidgets('an empty uid does not count as authenticated', (tester) async {
      final context = await _context(tester);

      expect(
        _redirect(
          context,
          RouteNames.dashboard,
          user: UserEntity(
            uid: '',
            email: '',
            displayName: '',
            createdAt: DateTime(2026, 9),
          ),
          hasHouse: false,
          resolved: true,
        ),
        RouteNames.login,
      );
    });
  });

  group('AuthGuard — callers that report no resolution state', () {
    testWidgets('keeps the pre-existing behaviour', (tester) async {
      final context = await _context(tester);

      // These call the guard directly, because the point is the defaults: a
      // caller with no resolution state to report gets exactly the old
      // decisions — no house → Create House, house → Dashboard.
      expect(
        _guard.handleRedirect(
          context,
          _stateAt(RouteNames.dashboard),
          currentUser: _user,
        ),
        RouteNames.createHouse,
      );
      expect(
        _guard.handleRedirect(
          context,
          _stateAt(RouteNames.dashboard),
          currentUser: _user,
          hasHouse: true,
        ),
        isNull,
      );
    });
  });
}
