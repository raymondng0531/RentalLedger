import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/app/router/reset_deep_link.dart';

/// Guards the Firebase in-app reset deep-link → GoRouter location mapping.
///
/// Firebase's `handleCodeInApp` reset email opens the web app with
/// `?mode=resetPassword&oobCode=…` in the query string. For a full page load
/// GoRouter would otherwise start at the splash route, so
/// [resolveResetDeepLinkLocation] turns a reset action link into the
/// `/reset-password` initial location (query string preserved) and returns
/// `null` for everything else — ordinary page loads, or reset links lacking a
/// usable code (which must never force the reset route).
void main() {
  group('resolveResetDeepLinkLocation', () {
    test('maps a Firebase reset action link to /reset-password with its query',
        () {
      final uri = Uri.parse(
        'https://rental-ledger-app.web.app/'
        '?mode=resetPassword&oobCode=ABC123&apiKey=key&lang=en',
      );
      expect(
        resolveResetDeepLinkLocation(uri),
        '/reset-password?mode=resetPassword&oobCode=ABC123&apiKey=key&lang=en',
      );
    });

    test('preserves a query with only mode + oobCode', () {
      final uri = Uri.parse('/?mode=resetPassword&oobCode=XYZ');
      expect(
        resolveResetDeepLinkLocation(uri),
        '/reset-password?mode=resetPassword&oobCode=XYZ',
      );
    });

    test('returns null for a non-reset mode (ordinary page load)', () {
      expect(
        resolveResetDeepLinkLocation(
          Uri.parse('https://rental-ledger-app.web.app/?mode=signIn&oobCode=Q'),
        ),
        isNull,
      );
    });

    test('returns null when there is no mode at all', () {
      expect(resolveResetDeepLinkLocation(Uri.parse('/login')), isNull);
      expect(resolveResetDeepLinkLocation(Uri.base), isNull);
    });

    test('returns null when the reset code is missing or empty', () {
      expect(
        resolveResetDeepLinkLocation(
          Uri.parse('?mode=resetPassword&apiKey=key'),
        ),
        isNull,
      );
      expect(
        resolveResetDeepLinkLocation(
          Uri.parse('?mode=resetPassword&oobCode='),
        ),
        isNull,
      );
    });
  });
}
