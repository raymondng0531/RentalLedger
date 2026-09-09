import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/domain/entities/user_entity.dart';
import 'route_names.dart';

/// Route guard that redirects users based on authentication status.
///
/// Rules:
/// - Unauthenticated users → Login page
/// - Authenticated users at auth pages → Dashboard
/// - Authenticated users without a house → Create House page
class AuthGuard {
  /// Evaluates the current route and returns a redirect path
  /// if the user should be sent elsewhere, or `null` to proceed.
  String? handleRedirect(
    BuildContext context,
    GoRouterState state, {
    UserEntity? currentUser,
    bool hasHouse = false,
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
