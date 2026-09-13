import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/firebase_service.dart' show firebaseInitResultProvider;
import '../../../../l10n/generated/app_localizations.dart';
import '../../../members/data/datasources/house_remote_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/auth_error_codes.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

// ───── Auth error messages ─────

/// The message to show the user for a failure carrying an [AuthErrorCodes]
/// [code].
///
/// This is the one place an auth error code becomes words on screen: the
/// data/domain layers attach a code and stay free of `BuildContext` and
/// `AppLocalizations` (see [AuthErrorCodes]), and the pages call this with the
/// localization instance they already hold.
///
/// A failure with no code, or a code this does not recognise, falls back to the
/// shared generic sentence — deliberately NOT to the failure's own `message`,
/// so neither raw Firebase text nor an untranslated English fallback can reach
/// the user in a Malay session.
String localizeAuthError(AppLocalizations l10n, String? code) {
  switch (code) {
    case AuthErrorCodes.cancelled:
      return l10n.authSignInCancelled;
    case AuthErrorCodes.invalidEmail:
      return l10n.authErrorInvalidEmail;
    case AuthErrorCodes.userDisabled:
      return l10n.authErrorUserDisabled;
    case AuthErrorCodes.userNotFound:
      return l10n.authErrorUserNotFound;
    case AuthErrorCodes.wrongPassword:
    case AuthErrorCodes.invalidCredential:
      return l10n.authErrorInvalidCredentials;
    case AuthErrorCodes.emailAlreadyInUse:
      return l10n.authErrorEmailAlreadyInUse;
    case AuthErrorCodes.operationNotAllowed:
      return l10n.authErrorOperationNotAllowed;
    case AuthErrorCodes.tooManyRequests:
      return l10n.authErrorTooManyRequests;
    case AuthErrorCodes.weakPassword:
      return l10n.authErrorWeakPassword;
    case AuthErrorCodes.invalidActionCode:
      return l10n.authErrorInvalidActionCode;
    case AuthErrorCodes.expiredActionCode:
      return l10n.authErrorExpiredActionCode;
    case AuthErrorCodes.networkRequestFailed:
      return l10n.authErrorNetworkFailed;
    case AuthErrorCodes.requiresRecentLogin:
      return l10n.authErrorRequiresRecentLogin;
    case AuthErrorCodes.missingActionCode:
      return l10n.authErrorMissingActionCode;
    case AuthErrorCodes.verifyLinkFailed:
      return l10n.authErrorVerifyLinkFailed;
    case AuthErrorCodes.notConfigured:
      return l10n.authErrorNotConfigured;
    default:
      return l10n.errorGenericMessage;
  }
}

// ───── Repository Provider ─────

/// Provides the [AuthRepository] implementation.
///
/// Returns a no-op stub when Firebase is not configured so the app
/// doesn't crash — it will show the Firebase setup error instead.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final firebaseResult = ref.watch(firebaseInitResultProvider);

  if (!firebaseResult.isSuccess) {
    return _NoOpAuthRepository();
  }

  // Keeps the user's own ACTIVE member rows' photo in step with the Auth
  // photo after a sign-in or a profile edit — see [MemberDisplayInfoSync].
  // The members data source is used directly (rather than through
  // houseRepositoryProvider) because house_provider already depends on this
  // one; going the other way would make the two providers import each other.
  final repo = AuthRepositoryImpl(
    remoteDataSource: AuthRemoteDataSource(),
    syncMemberDisplayInfo: HouseRemoteDataSource().updateMemberDisplayInfo,
  );

  // Clean up the auth subscription when the provider is disposed.
  ref.onDispose(() => repo.dispose());

  return repo;
});

// ───── Auth State Provider ─────

/// Exposes the current authentication state.
///
/// - `AsyncValue.data(null)` → Not authenticated
/// - `AsyncValue.data(UserEntity)` → Authenticated
/// - `AsyncValue.loading()` → Checking auth state (splash screen)
/// - `AsyncValue.error()` → Something went wrong
final authStateProvider = StreamProvider<UserEntity?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});

// ───── Current User Provider ─────

/// Quick access to the current user, or `null`.
///
/// This is a synchronous snapshot. For reactive updates, use [authStateProvider].
final currentUserProvider = Provider<UserEntity?>((ref) {
  return ref.watch(authRepositoryProvider).currentUser;
});

// ───── Login Provider ─────

/// Notifier that handles login requests and exposes loading/error state.
final loginProvider =
    AutoDisposeAsyncNotifierProvider<LoginNotifier, void>(LoginNotifier.new);

class LoginNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns `null` on success, or the [Failure] to report.
  ///
  /// As with [SocialLoginNotifier.loginWith], the failure itself is handed back
  /// rather than its message so the page can resolve [Failure.code] to a
  /// localized string (see [localizeAuthError]).
  Future<Failure?> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.login(email, password);
      state = const AsyncValue.data(null);
      return null; // null = success
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return const AuthenticationFailure(
          'An unexpected error occurred.', AuthErrorCodes.unexpected);
    }
  }
}

// ───── Logout Provider ─────

final logoutProvider =
    AutoDisposeAsyncNotifierProvider<LogoutNotifier, void>(LogoutNotifier.new);

class LogoutNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> logout() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.logout();
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
    }
  }
}

// ───── Social Login Provider ─────

final socialLoginProvider =
    AutoDisposeAsyncNotifierProvider<SocialLoginNotifier, void>(
        SocialLoginNotifier.new);

class SocialLoginNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Signs in with Google or Apple.
  ///
  /// Returns `null` on success, or the [Failure] to report. It hands back the
  /// failure itself rather than just its message so the caller can branch on
  /// [Failure.code] — which is how a cancelled sign-in is recognised without
  /// comparing the (translatable) message. See `AuthErrorCodes`.
  Future<Failure?> loginWith(String provider) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      if (provider == 'google') {
        await repo.loginWithGoogle();
      } else if (provider == 'apple') {
        await repo.loginWithApple();
      }
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e;
    } catch (e) {
      // Not a Failure, so there is no code to carry. `UnknownFailure` has no
      // `code` field, so the page's code→message mapping lands on its generic
      // sentence rather than this message — which stays English on purpose,
      // as a log/fallback value no user reads.
      state = AsyncValue.error(e, StackTrace.current);
      return const UnknownFailure('An unexpected error occurred.');
    }
  }
}

// ───── Register Provider ─────

final registerProvider =
    AutoDisposeAsyncNotifierProvider<RegisterNotifier, void>(RegisterNotifier.new);

class RegisterNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns `null` on success, or the [Failure] to report — see
  /// [LoginNotifier.login] for why the failure (not its message) is returned.
  Future<Failure?> register(
      String email, String password, String displayName) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.register(email, password, displayName);
      state = const AsyncValue.data(null);
      return null; // null = success
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return const AuthenticationFailure(
          'An unexpected error occurred.', AuthErrorCodes.unexpected);
    }
  }
}

// ───── Forgot Password Provider ─────

final forgotPasswordProvider = AutoDisposeAsyncNotifierProvider<
    ForgotPasswordNotifier, void>(ForgotPasswordNotifier.new);

class ForgotPasswordNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns `null` on success, or the [Failure] to report — see
  /// [LoginNotifier.login] for why the failure (not its message) is returned.
  Future<Failure?> sendResetEmail(String email) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.forgotPassword(email);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return const AuthenticationFailure(
          'An unexpected error occurred.', AuthErrorCodes.unexpected);
    }
  }
}

// ───── Reset Password Provider ─────

/// Lifecycle phase of the in-app password reset page.
enum ResetPasswordStatus {
  /// Validating the Firebase action code (page-level spinner).
  verifying,

  /// Code is valid — the branded new-password form is shown.
  ready,

  /// Code is missing, invalid, or expired — show a "request a new link" state.
  linkInvalid,

  /// Reset is being submitted (button spinner).
  submitting,

  /// Password changed successfully.
  success,

  /// Reset failed (e.g. weak password, already-used code) — inline error.
  failed,
}

/// Immutable view-model for the reset page.
class ResetPasswordState {
  const ResetPasswordState(this.status, {this.email, this.message, this.code});

  const ResetPasswordState.verifying() : this(ResetPasswordStatus.verifying);

  const ResetPasswordState.ready(String email)
      : this(ResetPasswordStatus.ready, email: email);

  const ResetPasswordState.linkInvalid([String? message, String? code])
      : this(ResetPasswordStatus.linkInvalid, message: message, code: code);

  const ResetPasswordState.submitting() : this(ResetPasswordStatus.submitting);

  const ResetPasswordState.success() : this(ResetPasswordStatus.success);

  const ResetPasswordState.failed([String? message, String? code])
      : this(ResetPasswordStatus.failed, message: message, code: code);

  final ResetPasswordStatus status;

  /// Account the (valid) action code was issued for.
  final String? email;

  /// English fallback detail for [ResetPasswordStatus.linkInvalid] / failed.
  ///
  /// Kept for callers with no localization to hand; the page prefers [code].
  final String? message;

  /// Stable [AuthErrorCodes] code for [message], when the failure carried one.
  ///
  /// The page resolves this to a localized string (see [localizeAuthError]);
  /// [message] is only the fallback for a failure that has no code.
  final String? code;
}

final resetPasswordProvider = AutoDisposeAsyncNotifierProvider<
    ResetPasswordNotifier, ResetPasswordState>(ResetPasswordNotifier.new);

class ResetPasswordNotifier
    extends AutoDisposeAsyncNotifier<ResetPasswordState> {
  @override
  Future<ResetPasswordState> build() async =>
      const ResetPasswordState.verifying();

  /// Validates [oobCode] against Firebase. On success the page shows the
  /// new-password form; on a missing/invalid/expired code it shows the
  /// "link problem" state. Never fabricates a reset UI for an unverified code.
  Future<void> verify(String oobCode) async {
    if (oobCode.isEmpty) {
      state = const AsyncValue.data(ResetPasswordState.linkInvalid(
        'This reset link is missing its code. Please request a new one.',
        AuthErrorCodes.missingActionCode,
      ));
      return;
    }
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final email = await repo.verifyResetCode(oobCode);
      state = AsyncValue.data(ResetPasswordState.ready(email ?? ''));
    } on Failure catch (e) {
      state = AsyncValue.data(ResetPasswordState.linkInvalid(e.message, e.code));
    } catch (e) {
      state = const AsyncValue.data(ResetPasswordState.linkInvalid(
        'We could not verify this reset link. Please request a new one.',
        AuthErrorCodes.verifyLinkFailed,
      ));
    }
  }

  /// Submits the real Firebase reset for [oobCode] with [newPassword].
  Future<void> reset({
    required String oobCode,
    required String newPassword,
  }) async {
    state = const AsyncValue.data(ResetPasswordState.submitting());
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.resetPassword(oobCode: oobCode, newPassword: newPassword);
      state = const AsyncValue.data(ResetPasswordState.success());
    } on Failure catch (e) {
      state = AsyncValue.data(ResetPasswordState.failed(e.message, e.code));
    } catch (e) {
      state = const AsyncValue.data(ResetPasswordState.failed(
        'Something went wrong. Please try again.',
        AuthErrorCodes.unexpected,
      ));
    }
  }
}

// ───── No-OP Stub (used when Firebase is not configured) ─────

class _NoOpAuthRepository implements AuthRepository {
  final _notifier = ValueNotifier<UserEntity?>(null);

  @override
  ValueNotifier<UserEntity?> get currentUserNotifier => _notifier;

  @override
  UserEntity? get currentUser => null;

  @override
  Stream<UserEntity?> authStateChanges() => Stream.value(null);

  @override
  Future<UserEntity> login(String email, String password) =>
      throw const FirebaseFailure('Firebase is not configured.',
          code: AuthErrorCodes.notConfigured);

  @override
  Future<UserEntity> loginWithGoogle() =>
      throw const FirebaseFailure('Firebase is not configured.',
          code: AuthErrorCodes.notConfigured);

  @override
  Future<UserEntity> loginWithApple() =>
      throw const FirebaseFailure('Firebase is not configured.',
          code: AuthErrorCodes.notConfigured);

  @override
  Future<UserEntity> register(String email, String password, String displayName) =>
      throw const FirebaseFailure('Firebase is not configured.',
          code: AuthErrorCodes.notConfigured);

  @override
  Future<void> logout() async {}

  @override
  Future<void> forgotPassword(String email) =>
      throw const FirebaseFailure('Firebase is not configured.',
          code: AuthErrorCodes.notConfigured);

  @override
  Future<String?> verifyResetCode(String oobCode) =>
      throw const FirebaseFailure('Firebase is not configured.',
          code: AuthErrorCodes.notConfigured);

  @override
  Future<void> resetPassword({
    required String oobCode,
    required String newPassword,
  }) =>
      throw const FirebaseFailure('Firebase is not configured.',
          code: AuthErrorCodes.notConfigured);

  @override
  Future<void> updateProfile({String? displayName, String? photoUrl}) =>
      throw const FirebaseFailure('Firebase is not configured.',
          code: AuthErrorCodes.notConfigured);

  @override
  Future<String> uploadProfilePhoto({required String localPath}) =>
      throw const FirebaseFailure('Firebase is not configured.',
          code: AuthErrorCodes.notConfigured);
}
