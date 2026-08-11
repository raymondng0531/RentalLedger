import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/extensions/string_extensions.dart';

void main() {
  group('StringExtensions.capitalize', () {
    test('capitalizes first letter', () {
      expect('hello'.capitalize, 'Hello');
    });

    test('handles empty string', () {
      expect(''.capitalize, '');
    });
  });

  group('StringExtensions.titleCase', () {
    test('capitalizes each word', () {
      expect('hello world'.titleCase, 'Hello World');
    });
  });

  group('StringExtensions.isValidEmail', () {
    test('valid emails pass', () {
      expect('user@example.com'.isValidEmail, isTrue);
      expect('first.last@domain.co'.isValidEmail, isTrue);
    });

    test('invalid emails fail', () {
      expect('not-an-email'.isValidEmail, isFalse);
      expect('missing@tld'.isValidEmail, isFalse);
      expect(''.isValidEmail, isFalse);
    });
  });

  group('StringExtensions.isValidUuid', () {
    test('valid UUIDs pass', () {
      expect(
        '123e4567-e89b-12d3-a456-426614174000'.isValidUuid,
        isTrue,
      );
    });

    test('invalid strings fail', () {
      expect('not-a-uuid'.isValidUuid, isFalse);
    });
  });

  group('StringExtensions.truncate', () {
    test('short strings stay unchanged', () {
      expect('hi'.truncate(5), 'hi');
    });

    test('long strings are truncated', () {
      expect('hello world'.truncate(5), 'hello...');
    });
  });
}
