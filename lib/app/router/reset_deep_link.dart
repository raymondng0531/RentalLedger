import 'route_names.dart';

/// Returns the `/reset-password` deep-link location (query string included)
/// when [uri] is a Firebase password-reset action link, else `null`.
///
/// Firebase's in-app (`handleCodeInApp`) reset email opens the continue URL
/// with `mode=resetPassword` + `oobCode` in the query. GoRouter uses this as
/// its initial location so the reset route runs even on a full page load where
/// the router would otherwise start at [RouteNames.splash]. Any other URI —
/// an ordinary page load, or a reset link without a usable code — returns
/// `null` so the router never force-opens the reset page for the wrong link.
///
/// Kept as a pure top-level function (no Flutter/web imports) so the mapping
/// is unit-testable on the Dart VM.
String? resolveResetDeepLinkLocation(Uri uri) {
  if (uri.queryParameters['mode'] != 'resetPassword') return null;
  final code = uri.queryParameters['oobCode'];
  if (code == null || code.isEmpty) return null;
  final query = uri.hasQuery ? uri.query : '';
  return query.isEmpty
      ? RouteNames.resetPassword
      : '${RouteNames.resetPassword}?$query';
}
