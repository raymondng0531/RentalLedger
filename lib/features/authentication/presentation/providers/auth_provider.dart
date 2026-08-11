import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/firebase_service.dart' show firebaseInitResultProvider;
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

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

  final repo = AuthRepositoryImpl(
    remoteDataSource: AuthRemoteDataSource(),
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

  Future<String?> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.login(email, password);
      state = const AsyncValue.data(null);
      return null; // null = success
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
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

  /// Signs in with Google or Apple. Returns null on success, or an error message.
  Future<String?> loginWith(String provider) async {
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
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
    }
  }
}

// ───── Register Provider ─────

final registerProvider =
    AutoDisposeAsyncNotifierProvider<RegisterNotifier, void>(RegisterNotifier.new);

class RegisterNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> register(
      String email, String password, String displayName) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.register(email, password, displayName);
      state = const AsyncValue.data(null);
      return null; // null = success
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
    }
  }
}

// ───── Forgot Password Provider ─────

final forgotPasswordProvider = AutoDisposeAsyncNotifierProvider<
    ForgotPasswordNotifier, void>(ForgotPasswordNotifier.new);

class ForgotPasswordNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> sendResetEmail(String email) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.forgotPassword(email);
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
      throw const FirebaseFailure('Firebase is not configured.');

  @override
  Future<UserEntity> loginWithGoogle() =>
      throw const FirebaseFailure('Firebase is not configured.');

  @override
  Future<UserEntity> loginWithApple() =>
      throw const FirebaseFailure('Firebase is not configured.');

  @override
  Future<UserEntity> register(String email, String password, String displayName) =>
      throw const FirebaseFailure('Firebase is not configured.');

  @override
  Future<void> logout() async {}

  @override
  Future<void> forgotPassword(String email) =>
      throw const FirebaseFailure('Firebase is not configured.');

  @override
  Future<void> updateProfile({String? displayName, String? photoUrl}) =>
      throw const FirebaseFailure('Firebase is not configured.');

  @override
  Future<String> uploadProfilePhoto({required String localPath}) =>
      throw const FirebaseFailure('Firebase is not configured.');
}
