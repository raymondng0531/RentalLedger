import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/utils/member_name_utils.dart';

void main() {
  group('emailLocalPartName', () {
    test('extracts the local part of a standard email', () {
      expect(emailLocalPartName('john@example.com'), 'john');
      expect(emailLocalPartName('raymo@gmail.com'), 'raymo');
    });

    test('returns null for empty input', () {
      expect(emailLocalPartName(null), isNull);
      expect(emailLocalPartName(''), isNull);
      expect(emailLocalPartName('   '), '   ');
    });

    test('returns the whole string when there is no @', () {
      expect(emailLocalPartName('not-an-email'), 'not-an-email');
    });

    test('handles an @ at the start (degenerate email)', () {
      expect(emailLocalPartName('@x.com'), '@x.com');
    });
  });

  group('pickDisplayName', () {
    test('the user profile wins over the member record cache', () {
      expect(
        pickDisplayName(
          profileName: 'Raymo',
          memberDisplayName: 'Old Stale Name',
          profileEmail: 'raymo@example.com',
          memberEmail: 'raymo@example.com',
        ),
        'Raymo',
      );
    });

    test('a fresh profile edit is never shadowed by a stale member record', () {
      // Root-cause regression: the member record used to win, so editing the
      // profile left old names on screen until a manual refresh.
      expect(
        pickDisplayName(
          profileName: 'New Name',
          profileEmail: null,
          memberDisplayName: 'Stale Member Name',
        ),
        'New Name',
      );
    });

    test('empty profile name falls back to the member record', () {
      expect(
        pickDisplayName(
          profileName: '',
          profileEmail: null,
          memberDisplayName: 'Member Name',
          memberEmail: 'member@example.com',
        ),
        'Member Name',
      );
    });

    test('no profile, no member name → member email local part', () {
      expect(
        pickDisplayName(
          profileName: null,
          profileEmail: null,
          memberEmail: 'alice@example.com',
        ),
        'alice',
      );
    });

    test('no member email → profile email local part', () {
      expect(
        pickDisplayName(
          profileName: null,
          profileEmail: 'bob@example.com',
        ),
        'bob',
      );
    });

    test('returns null when nothing resolves', () {
      expect(
        pickDisplayName(
          profileName: null,
          profileEmail: null,
          memberDisplayName: '',
          memberEmail: '',
        ),
        isNull,
      );
    });
  });
}
