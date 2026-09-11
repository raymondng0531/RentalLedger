import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/domain/entities/user_entity.dart';
import 'route_names.dart';

/// Route guard that redirects users based on authentication status.
///
/// Rules:
/// - Unauthenticated users → Login page
/// - Authenticated users whose house lookup hasn't finished → stay on Splash
/// - Authenticated users at auth pages → Dashboard
/// - Authenticated users without a house → Create House page
class AuthGuard {
  /// Evaluates the current route and returns a redirect path
  /// if the user should be sent elsewhere, or `null` to proceed.
  ///
  /// [hasHouse] and [isHouseResolved] are deliberately two separate inputs:
  /// "the lookup hasn't finished" and "the lookup finished, and this user has
  /// no house" are different states, and only the second one belongs on the
  /// Create House screen. [isHouseResolved] defaults to `true` so a caller that
  /// has no resolution state to report gets the pre-existing behaviour.
  String? handleRedirect(
    BuildContext context,
    GoRouterState state, {
    UserEntity? currentUser,
    bool hasHouse = false,
    bool isHouseResolved = true,
  }) {
    final isAuthenticated = currentUser != null && currentUser.uid.isNotEmpty;
    final location = state.uri.toString();

    // The in-app password-reset deep link must be reachable both signed-out
    // and signed-in (a member can click their reset email while logged in). It
    // is always allowed — the reset page itself validates the Firebase action
    // code and, on success, sends the user back to sign in.
    if (_isResetRoute(location)) return null;

    final isAuthRoute = _isAuthRoute(location);
    final isOnboardingRoute = _isOnboardingRoute(location);

    // Authenticated, and we do not know yet whether this user has a house.
    //
    // This is the state the old `hasHouse == false` test could not tell apart
    // from "no house": on a cold start the session is restored before the house
    // lookup finishes, so a member who DOES have a house was sent to Create
    // House — and then on to the Dashboard once their house arrived. Hold on
    // the splash (the app's loading state) instead of flashing a page that is
    // wrong for them, and let the router re-evaluate when the resolution
    // notifier flips: this app's router observes it, so the answer always
    // arrives. Staying put when already there is what keeps this from
    // bouncing against the auth-route rule below.
    if (isAuthenticated && !isHouseResolved && !hasHouse) {
      return _isSplashRoute(location) ? null : RouteNames.splash;
    }

    // Authenticated user on auth page → go to dashboard.
    if (isAuthenticated && isAuthRoute) {
      return RouteNames.dashboard;
    }

    // Authenticated user without house → redirect to create/join.
    if (isAuthenticated && !hasHouse && !isOnboardingRoute) {
      return RouteNames.createHouse;
    }

    // Authenticated user with house on onboarding → go to dashboard.
    if (isAuthenticated && hasHouse && isOnboardingRoute) {
      return RouteNames.dashboard;
    }

    // Unauthenticated user on protected page → go to login.
    if (!isAuthenticated && !isAuthRoute && !isOnboardingRoute) {
      return RouteNames.login;
    }

    // No redirect needed.
    return null;
  }

  bool _isSplashRoute(String location) => location == RouteNames.splash;

  bool _isAuthRoute(String location) {
    return location == RouteNames.login ||
        location == RouteNames.register ||
        location == RouteNames.splash ||
        location == RouteNames.forgotPassword;
  }

  /// True when the location is the reset-password route.
  ///
  /// Auth routes above are matched by exact string equality because they carry
  /// no query string; the reset route is opened with Firebase action-code query
  /// params (`?mode=resetPassword&oobCode=…`), so it must be matched by path.
  bool _isResetRoute(String location) {
    final path = Uri.tryParse(location)?.path;
    return path != null && path == RouteNames.resetPassword;
  }

  bool _isOnboardingRoute(String location) {
    return location == RouteNames.createHouse ||
        location == RouteNames.joinHouse;
  }
}
