import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/widgets/activity_card.dart';

void main() {
  group('formatMemberName', () {
    test('title-cases an all-caps name', () {
      expect(formatMemberName('RAYMOND NG'), 'Raymond Ng');
    });

    test('handles multiple words', () {
      expect(
        formatMemberName('RAYMOND NG CHIAN QUAN'),
        'Raymond Ng Chian Quan',
      );
    });

    test('leaves already-cased names untouched', () {
      expect(formatMemberName('Raymond Ng'), 'Raymond Ng');
    });

    test('does not treat the literal name "Member" as a placeholder', () {
      // "Member" is a valid real display name — it must never be altered.
      expect(formatMemberName('Member'), 'Member');
    });

    test('returns empty string for empty input', () {
      expect(formatMemberName(''), '');
    });
  });

  group('shortMemberName', () {
    test('shortens a long name to the first two words', () {
      expect(shortMemberName('RAYMOND NG CHIAN QUAN / UPM'), 'Raymond Ng');
    });

    test('keeps a short name as-is', () {
      expect(shortMemberName('Ali'), 'Ali');
      expect(shortMemberName('Raymond Ng'), 'Raymond Ng');
    });

    test('keeps the literal name "Member" intact', () {
      // A real display name of "Member" is valid and must survive shortening.
      expect(shortMemberName('Member'), 'Member');
    });
  });
}
