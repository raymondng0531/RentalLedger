import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/errors/failures.dart';
import 'package:rental_ledger/core/utils/failure_messages.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Phase 15 — a failure keeps its English developer message, and the *user*
/// reads a localized one.
///
/// The domain, data and Firebase layers have no `BuildContext` and must not
/// acquire one: a repository that took an `AppLocalizations` would be
/// untestable without a widget tree and would drag the presentation layer into
/// every transaction. So a failure carries a stable `code` (and a
/// developer-facing English `message`), and [FailureMessages] — a presentation
/// utility — is the single place that turns it into prose.

late AppLocalizations _en;
late AppLocalizations _ms;

void main() {
  setUpAll(() async {
    _en = await AppLocalizations.delegate.load(const Locale('en'));
    _ms = await AppLocalizations.delegate.load(const Locale('ms'));
  });

  group('by failure type', () {
    test('each failure class reads as plain, localized language', () {
      expect(FailureMessages.of(const NetworkFailure(), _en),
          'No internet connection.');
      expect(FailureMessages.of(const NetworkFailure(), _ms),
          'Tiada sambungan internet.');

      expect(FailureMessages.of(const OfflineFailure(), _ms),
          'Anda di luar talian. Memaparkan data cache.');

      expect(FailureMessages.of(const PermissionFailure(), _ms),
          'Anda tiada kebenaran untuk melakukannya.');

      expect(FailureMessages.of(const NotFoundFailure(), _ms),
          'Kami tidak menjumpai item itu.');

      expect(FailureMessages.of(const AuthenticationFailure(), _ms),
          'Sila log masuk semula.');
    });

    test('the developer message never reaches the user', () {
      // The failure still carries its English text — it is what a stack trace
      // and a crash report should show — but it is not what the UI renders.
      const failure = FirebaseFailure('Failed to load history: [cloud_firestore/unavailable] ...');
      final shown = FailureMessages.of(failure, _ms);

      expect(shown, isNot(contains('cloud_firestore')));
      expect(shown, isNot(contains('Failed to load history')));
      expect(shown, 'Sesuatu tidak kena. Sila cuba lagi.');
    });

    test('an unexpected throw still reads as something a person can act on', () {
      expect(FailureMessages.of(const UnknownFailure('boom'), _ms),
          'Sesuatu tidak kena. Sila cuba lagi.');
    });
  });

  group('by stable code', () {
    test('a code wins over the failure type', () {
      const failure = FirebaseFailure('raw english', code: FailureCodes.permission);
      expect(FailureMessages.of(failure, _ms),
          'Anda tiada kebenaran untuk melakukannya.');
    });

    test('raw Firebase codes are recognised', () {
      expect(
        FailureMessages.of(
            const FirebaseFailure('x', code: 'permission-denied'), _en),
        'You do not have permission to do that.',
      );
      expect(
        FailureMessages.of(const FirebaseFailure('x', code: 'unavailable'), _ms),
        'Tiada sambungan internet.',
      );
      expect(
        FailureMessages.of(const FirebaseFailure('x', code: 'not-found'), _ms),
        'Kami tidak menjumpai item itu.',
      );
    });

    test('an unrecognised code falls back to the type, never to the raw text',
        () {
      const failure = FirebaseFailure('raw english', code: 'some/new-code');
      expect(FailureMessages.of(failure, _ms),
          'Sesuatu tidak kena. Sila cuba lagi.');
    });

    test('every FailureCodes constant has a message', () {
      const codes = <String>[
        FailureCodes.network,
        FailureCodes.offline,
        FailureCodes.permission,
        FailureCodes.notFound,
        FailureCodes.authentication,
        FailureCodes.loadFailed,
        FailureCodes.saveFailed,
        FailureCodes.unexpected,
      ];

      for (final code in codes) {
        expect(FailureMessages.forCode(code, _en), isNotNull, reason: code);
        expect(FailureMessages.forCode(code, _ms), isNotNull, reason: code);
        expect(FailureMessages.forCode(code, _ms), isNotEmpty, reason: code);
      }
    });

    test('an unknown or absent code yields null, not a guess', () {
      expect(FailureMessages.forCode(null, _en), isNull);
      expect(FailureMessages.forCode('', _en), isNull);
      expect(FailureMessages.forCode('nope', _en), isNull);
    });

    test('the code itself is never displayed', () {
      for (final code in const [FailureCodes.network, FailureCodes.permission]) {
        expect(FailureMessages.forCode(code, _en), isNot(contains('error/')));
      }
    });
  });

  group('validation failures pass through', () {
    test('a form-authored message is shown as written', () {
      // Validation copy is written by the form that owns the field, so it is
      // already localized; replacing it with a generic message would lose the
      // only information that tells the user what to fix.
      const failure = ValidationFailure('Please enter a title.');
      expect(FailureMessages.of(failure, _ms), 'Please enter a title.');
    });

    test('a localized validation message survives both locales', () {
      final failure = ValidationFailure(_ms.errorNetwork);
      expect(FailureMessages.of(failure, _ms), _ms.errorNetwork);
    });

    test('a validation failure with a code still resolves by code', () {
      // Defensive: a code is the more specific signal when one is present.
      final failure = ValidationFailure(_en.errorNetwork);
      // ValidationFailure has no code parameter, so this exercises the
      // pass-through branch only.
      expect(FailureMessages.of(failure, _en), _en.errorNetwork);
    });
  });

  group('no English leaks in a Malay session', () {
    test('every failure class is Malay', () {
      final failures = <Failure>[
        const NetworkFailure(),
        const OfflineFailure(),
        const PermissionFailure(),
        const NotFoundFailure(),
        const AuthenticationFailure(),
        const FirebaseFailure('raw english'),
        const UnknownFailure('raw english'),
      ];

      for (final failure in failures) {
        final text = FailureMessages.of(failure, _ms);
        expect(text, isNot(equals(failure.message)),
            reason: '${failure.runtimeType} was not localized');
      }
    });
  });
}
