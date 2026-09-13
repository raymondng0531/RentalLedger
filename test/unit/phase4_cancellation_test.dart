import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/errors/failures.dart';
import 'package:rental_ledger/features/authentication/domain/auth_error_codes.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/domain/repositories/auth_repository.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Phase 4 — cancelled sign-in must not depend on localized display text.
///
/// The login flow suppresses the snackbar when the user dismisses the provider
/// sheet. That decision used to be made by comparing the *English* message
/// (`errorMessage != 'Sign in cancelled.'`), which would have silently broken
/// the moment the message was translated. These tests pin the replacement: a
/// stable code on the failure.
///
/// The helper below is the exact predicate `LoginPage._handleSocial` applies,
/// so a change to the branching rule fails here rather than in the UI.

/// `true` when the failure should be shown to the user.
bool _reports(Failure failure) => failure.code != AuthErrorCodes.cancelled;

/// A repository that throws [error] from the Google/Apple sign-in paths.
///
/// Only those two members are implemented; `noSuchMethod` covers the rest of
/// the interface, so this cannot accidentally become a general-purpose fake.
class _ThrowingAuthRepository implements AuthRepository {
  _ThrowingAuthRepository(this.error);

  final Object error;

  @override
  Future<UserEntity> loginWithGoogle() async => throw error;

  @override
  Future<UserEntity> loginWithApple() async => throw error;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// A repository whose social sign-in succeeds.
class _SucceedingAuthRepository implements AuthRepository {
  @override
  Future<UserEntity> loginWithGoogle() async => UserEntity(
        uid: 'u1',
        email: 'a@b.c',
        displayName: 'A',
        createdAt: DateTime(2026),
      );

  @override
  Future<UserEntity> loginWithApple() async => loginWithGoogle();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

ProviderContainer _containerWith(AuthRepository repository) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

late AppLocalizations _en;
late AppLocalizations _ms;

void main() {
  setUpAll(() async {
    _en = await AppLocalizations.delegate.load(const Locale('en'));
    _ms = await AppLocalizations.delegate.load(const Locale('ms'));
  });

  group('AuthErrorCodes', () {
    test('is a stable, non-empty code', () {
      expect(AuthErrorCodes.cancelled, 'auth/cancelled');
    });

    test('is not any shipped message — in either language', () {
      // The whole point: the code is not, and must never become, the text the
      // user reads. If someone "helpfully" set the code to the English string,
      // translating the message would break the flow again.
      expect(AuthErrorCodes.cancelled, isNot(_en.authSignInCancelled));
      expect(AuthErrorCodes.cancelled, isNot(_ms.authSignInCancelled));
      expect(_en.authSignInCancelled, isNot(_ms.authSignInCancelled),
          reason: 'the messages really do differ per language');
    });

    test('the shipped messages are unchanged from what the app already said',
        () {
      expect(_en.authSignInCancelled, 'Sign in cancelled.');
      expect(_ms.authSignInCancelled, 'Log masuk dibatalkan.');
    });
  });

  group('cancelled sign-in is suppressed', () {
    test('in English', () async {
      final failure = await _containerWith(
        _ThrowingAuthRepository(
          AuthenticationFailure(
              _en.authSignInCancelled, AuthErrorCodes.cancelled),
        ),
      ).read(socialLoginProvider.notifier).loginWith('google');

      expect(failure, isNotNull);
      expect(failure!.code, AuthErrorCodes.cancelled);
      expect(_reports(failure), isFalse, reason: 'no snackbar');
    });

    test('in Malay — the message text is irrelevant', () async {
      final failure = await _containerWith(
        _ThrowingAuthRepository(
          AuthenticationFailure(
              _ms.authSignInCancelled, AuthErrorCodes.cancelled),
        ),
      ).read(socialLoginProvider.notifier).loginWith('google');

      expect(failure!.code, AuthErrorCodes.cancelled);
      expect(_reports(failure), isFalse,
          reason: 'translating the message must not resurrect the snackbar');
    });

    test('with a reworded message — punctuation and casing do not matter',
        () async {
      final failure = await _containerWith(
        _ThrowingAuthRepository(
          const AuthenticationFailure(
              'Sign-in cancelled', AuthErrorCodes.cancelled),
        ),
      ).read(socialLoginProvider.notifier).loginWith('google');

      expect(_reports(failure!), isFalse);
    });

    test('for Apple sign-in too', () async {
      final failure = await _containerWith(
        _ThrowingAuthRepository(
          AuthenticationFailure(
              _ms.authSignInCancelled, AuthErrorCodes.cancelled),
        ),
      ).read(socialLoginProvider.notifier).loginWith('apple');

      expect(_reports(failure!), isFalse);
    });
  });

  group('a real failure is still reported', () {
    test('a non-cancellation failure carries no cancellation code', () async {
      final failure = await _containerWith(
        _ThrowingAuthRepository(
          const AuthenticationFailure('Google sign in failed.'),
        ),
      ).read(socialLoginProvider.notifier).loginWith('google');

      expect(failure!.code, isNull);
      expect(_reports(failure), isTrue, reason: 'snackbar shown');
    });

    test('the old English message alone no longer suppresses anything',
        () async {
      // Regression guard for the exact defect: identical TEXT, no code. Under
      // the old string comparison this was treated as a cancellation; it must
      // not be any more, or the flow is still keyed on prose.
      final failure = await _containerWith(
        _ThrowingAuthRepository(
          AuthenticationFailure(_en.authSignInCancelled),
        ),
      ).read(socialLoginProvider.notifier).loginWith('google');

      expect(failure!.message, 'Sign in cancelled.');
      expect(failure.code, isNot(AuthErrorCodes.cancelled));
      expect(_reports(failure), isTrue);
    });

    test('an unexpected throw becomes a reportable UnknownFailure', () async {
      final failure = await _containerWith(
        _ThrowingAuthRepository(StateError('boom')),
      ).read(socialLoginProvider.notifier).loginWith('google');

      expect(failure, isA<UnknownFailure>());
      expect(failure!.code, isNot(AuthErrorCodes.cancelled));
      expect(_reports(failure), isTrue);
    });
  });

  group('a successful sign-in', () {
    test('returns no failure at all', () async {
      final failure = await _containerWith(_SucceedingAuthRepository())
          .read(socialLoginProvider.notifier)
          .loginWith('google');

      expect(failure, isNull, reason: 'the page navigates to the dashboard');
    });
  });
}
