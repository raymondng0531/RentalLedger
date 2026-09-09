import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/errors/failures.dart';
import 'package:rental_ledger/features/authentication/domain/entities/user_entity.dart';
import 'package:rental_ledger/features/authentication/domain/repositories/auth_repository.dart';
import 'package:rental_ledger/features/authentication/presentation/providers/auth_provider.dart';

/// Guards the in-app (web) branded password-reset flow.
///
/// The reset page NEVER shows a new-password form for a code it has not
/// verified with Firebase: a missing / invalid / expired action code must land
/// on the "link problem" state (`ResetPasswordStatus.linkInvalid`) instead of a
/// form. Only a verified code leads to [ResetPasswordStatus.ready], and submit
/// performs the real Firebase reset — success → [ResetPasswordStatus.success],
/// failure → [ResetPasswordStatus.failed] with the surfaced message.
///
/// `authRepositoryProvider` is overridden with a deterministic fake so no
/// Firebase is touched and the transitions are fully asserted.
const _invalidMessage = 'This reset link is invalid. Please request a new one.';

/// A configurable [AuthRepository] double. Only [verifyResetCode] and
/// [resetPassword] are exercised by the reset notifier; the remaining members
/// are stubbed and never called.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.acceptedCode, this.resetError});

  /// The only action code [verifyResetCode] treats as valid.
  final String acceptedCode;

  /// When set, [resetPassword] throws it (e.g. a weak-password failure).
  final Failure? resetError;

  String? lastResetCode;
  String? lastNewPassword;

  final ValueNotifier<UserEntity?> _user = ValueNotifier<UserEntity?>(null);

  @override
  ValueNotifier<UserEntity?> get currentUserNotifier => _user;

  @override
  UserEntity? get currentUser => null;

  @override
  Stream<UserEntity?> authStateChanges() => const Stream.empty();

  @override
  Future<String?> verifyResetCode(String oobCode) async {
    if (oobCode == acceptedCode) return 'member@example.com';
    throw const AuthenticationFailure(_invalidMessage);
  }

  @override
  Future<void> resetPassword({
    required String oobCode,
    required String newPassword,
  }) async {
    lastResetCode = oobCode;
    lastNewPassword = newPassword;
    final error = resetError;
    if (error != null) throw error;
  }

  @override
  Future<UserEntity> login(String email, String password) =>
      throw UnimplementedError('not used in reset flow');

  @override
  Future<UserEntity> loginWithGoogle() => throw UnimplementedError();

  @override
  Future<UserEntity> loginWithApple() => throw UnimplementedError();

  @override
  Future<UserEntity> register(String email, String password, String displayName) =>
      throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> forgotPassword(String email) => throw UnimplementedError();

  @override
  Future<void> updateProfile({String? displayName, String? photoUrl}) =>
      throw UnimplementedError();

  @override
  Future<String> uploadProfilePhoto({required String localPath}) =>
      throw UnimplementedError();
}

/// A container whose auth repository is [repo]. A [ProviderSubscription] keeps
/// the auto-dispose reset provider alive across the awaited notifier calls, and
/// the notifier's initial `build()` is awaited so the emitted `verifying` state
/// is committed before any notifier method runs — the same sequencing the page
/// guarantees (see `ResetPasswordPage._startVerify`). Without this priming, a
/// state set synchronously (e.g. `verify`'s empty-code short-circuit) would be
/// overwritten by the just-built `verifying` state.
Future<ProviderContainer> _containerFor(_FakeAuthRepository repo) async {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  // Keep the auto-dispose notifier alive for the duration of the test.
  final sub = container.listen<AsyncValue<ResetPasswordState>>(
    resetPasswordProvider,
    (_, __) {},
  );
  addTearDown(() {
    sub.close();
    container.dispose();
  });
  await container.read(resetPasswordProvider.future);
  return container;
}

void main() {
  group('ResetPasswordNotifier.verify — link validation gating', () {
    test('an empty oobCode is treated as an invalid link (no form)', () async {
      final repo = _FakeAuthRepository(acceptedCode: 'good-code');
      final container = await _containerFor(repo);

      await container.read(resetPasswordProvider.notifier).verify('');

      final state = container.read(resetPasswordProvider).value;
      expect(state?.status, ResetPasswordStatus.linkInvalid);
      expect(state?.message, contains('missing its code'));
    });

    test('an invalid/unknown code lands on linkInvalid, not a form', () async {
      final repo = _FakeAuthRepository(acceptedCode: 'good-code');
      final container = await _containerFor(repo);

      await container.read(resetPasswordProvider.notifier).verify('bad-code');

      final state = container.read(resetPasswordProvider).value;
      expect(state?.status, ResetPasswordStatus.linkInvalid);
      expect(state?.message, _invalidMessage);
    });

    test('a valid code transitions to ready with the account email', () async {
      final repo = _FakeAuthRepository(acceptedCode: 'good-code');
      final container = await _containerFor(repo);

      await container.read(resetPasswordProvider.notifier).verify('good-code');

      final state = container.read(resetPasswordProvider).value;
      expect(state?.status, ResetPasswordStatus.ready);
      expect(state?.email, 'member@example.com');
    });
  });

  group('ResetPasswordNotifier.reset — real Firebase reset', () {
    test('success transitions to success and passes the verified code+password',
        () async {
      final repo = _FakeAuthRepository(acceptedCode: 'good-code');
      final container = await _containerFor(repo);
      final notifier = container.read(resetPasswordProvider.notifier);

      await notifier.verify('good-code');
      expect(container.read(resetPasswordProvider).value?.status,
          ResetPasswordStatus.ready);

      await notifier.reset(oobCode: 'good-code', newPassword: 'new-pass-123');

      expect(container.read(resetPasswordProvider).value?.status,
          ResetPasswordStatus.success);
      expect(repo.lastResetCode, 'good-code');
      expect(repo.lastNewPassword, 'new-pass-123');
    });

    test('a reset failure surfaces failed with the message (e.g. weak password)',
        () async {
      final repo = _FakeAuthRepository(
        acceptedCode: 'good-code',
        resetError: const AuthenticationFailure('Password is too weak.'),
      );
      final container = await _containerFor(repo);
      final notifier = container.read(resetPasswordProvider.notifier);

      await notifier.verify('good-code');
      await notifier.reset(oobCode: 'good-code', newPassword: 'short');

      final state = container.read(resetPasswordProvider).value;
      expect(state?.status, ResetPasswordStatus.failed);
      expect(state?.message, 'Password is too weak.');
    });
  });
}
