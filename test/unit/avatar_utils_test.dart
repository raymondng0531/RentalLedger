import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/utils/avatar_utils.dart';

void main() {
  group('avatarInitial', () {
    test('takes the first letter of a full name, uppercased', () {
      expect(avatarInitial('Raymond Ng'), 'R');
      expect(avatarInitial('John Tan'), 'J');
    });

    test('uppercases a lowercase name', () {
      expect(avatarInitial('haha'), 'H');
      expect(avatarInitial('raymond'), 'R');
    });

    test('trims surrounding whitespace before taking the initial', () {
      expect(avatarInitial('  Raymond Ng  '), 'R');
    });

    test('a whitespace-only name never renders a blank avatar', () {
      // Root-cause regression: an untrimmed whitespace string used to produce
      // a literal space as the "initial" — a visually blank circle.
      expect(avatarInitial('   '), '?');
      expect(avatarInitial('\t'), '?');
    });

    test('returns ? for null or empty display names', () {
      expect(avatarInitial(null), '?');
      expect(avatarInitial(''), '?');
    });
  });
}
