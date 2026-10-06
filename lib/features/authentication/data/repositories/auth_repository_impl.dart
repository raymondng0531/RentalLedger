import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/utils/member_profile_sync_utils.dart';
import '../../domain/auth_error_codes.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Writes the signed-in user's current display info onto their OWN active
/// house-membership rows.
///
/// Supplied by the members feature (`HouseRemoteDataSource
/// .updateMemberDisplayInfo`) and injected rather than imported, so the auth
/// data layer does not have to depend on the members data layer. Being a
/// function rather than a Firestore handle also makes the sync observable in
/// tests without a Firebase instance.
typedef MemberDisplayInfoSync = Future<void> Function({
  required String userId,
  String? displayName,
  String? photoUrl,
});

/// Implementation of [AuthRepository] backed by Firebase Auth + Firestore.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    MemberDisplayInfoSync? syncMemberDisplayInfo,
  })  : _remote = remoteDataSource,
        _memberDisplayInfoSync = syncMemberDisplayInfo {
    // Listen to Firebase auth state and update the notifier.
    _authSubscription = _remote.authStateChanges.listen(_onAuthStateChanged);

    // Check if there's already a signed-in user.
    final existingUser = _remote.currentUser;
    if (existingUser != null) {
      _currentUserNotifier.value = _firebaseUserToEntity(existingUser);
      // A restored session never passes through login(), so register this
      // device's push token here too (else push never reaches it).
      _savePushToken(existingUser.uid);
    }

    // iPhone Home Screen app: this load may be the return from a Google
    // redirect sign-in (see [loginWithGoogle]).
    if (_remote.usesGoogleRedirect) {
      unawaited(_completePendingGoogleRedirect());
    }
  }

  final AuthRemoteDataSource _remote;

  /// Optional membership-photo synchronizer. `null` when the members feature
  /// is not available (e.g. Firebase is unconfigured) — the sync is
  /// display-only, so its absence must not change any auth behaviour.
  final MemberDisplayInfoSync? _memberDisplayInfoSync;

  final ValueNotifier<UserEntity?> _currentUserNotifier =
      ValueNotifier<UserEntity?>(null);

  StreamSubscription<fb_auth.User?>? _authSubscription;

  @override
  ValueNotifier<UserEntity?> get currentUserNotifier => _currentUserNotifier;

  @override
  UserEntity? get currentUser => _currentUserNotifier.value;

  @override
  Stream<UserEntity?> authStateChanges() =>
      _remote.authStateChanges.map(_firebaseUserToEntity);

  @override
  Future<UserEntity> login(String email, String password) async {
    try {
      final credential = await _remote.login(email, password);
      final firebaseUser = credential.user!;

      // Update last login timestamp.
      _remote.updateLastLogin(firebaseUser.uid);

      _savePushToken(firebaseUser.uid);

      final userEntity = _firebaseUserToEntity(firebaseUser);
      _currentUserNotifier.value = userEntity;
      return userEntity;
    } on AuthException catch (e) {
      throw AuthenticationFailure(e.message, e.code);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure(
        'Login failed: ${e.toString()}',
        code: AuthErrorCodes.unexpected,
      );
    }
  }

  @override
  Future<UserEntity> loginWithGoogle() async {
    try {
      if (_remote.usesGoogleRedirect) {
        // iPhone Home Screen app: the page leaves for Google and the sign-in
        // is finished on return by [_completePendingGoogleRedirect]. The
        // button keeps its spinner while the page navigates. If it never
        // does, stand down as a quiet cancel so the user can try again.
        await _remote.startGoogleRedirect();
        await Future<void>.delayed(_redirectStandDown);
        throw const AuthException(
          'Sign in cancelled.',
          code: AuthErrorCodes.cancelled,
        );
      }

      final credential = await _remote.loginWithGoogle();
      return await _completeGoogleLogin(credential.user!);
    } on AuthException catch (e) {
      throw AuthenticationFailure(e.message, e.code);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure(
        'Google sign in failed: ${e.toString()}',
        code: AuthErrorCodes.unexpected,
      );
    }
  }

  /// How long [loginWithGoogle] waits for a redirect to leave the page.
  static const Duration _redirectStandDown = Duration(seconds: 30);

  /// Finishes a Google redirect sign-in when the Home Screen app reloads.
  ///
  /// Firebase restores the signed-in user by itself. This runs the same
  /// follow-up as the popup sign-in: profile document, push token and the
  /// member photo sync.
  Future<void> _completePendingGoogleRedirect() async {
    try {
      final credential = await _remote.completeGoogleRedirect();
      final firebaseUser = credential?.user;
      if (firebaseUser == null) return;
      await _completeGoogleLogin(firebaseUser);
    } catch (e) {
      debugPrint('[AuthRepository] Google redirect sign-in failed: $e');
    }
  }

  /// Post-sign-in steps shared by the Google popup and redirect flows.
  Future<UserEntity> _completeGoogleLogin(fb_auth.User firebaseUser) async {
    // Ensure a profile document exists for the new user.
    if (firebaseUser.displayName != null) {
      await _remote.createUserProfile(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName!,
        photoUrl: firebaseUser.photoURL,
      );
    }

    final userEntity = _firebaseUserToEntity(firebaseUser);
    _savePushToken(firebaseUser.uid);
    _currentUserNotifier.value = userEntity;

    // A returning Google user's Auth photo may have changed since they last
    // signed in. The member row keeps whatever it held, so the Members list
    // would show a different face from the header. PHOTO ONLY — never the
    // name, so a member's own display name is not overwritten by their
    // Google account name. Non-fatal: see [_syncMemberDisplayInfo].
    await _syncMemberDisplayInfo(
      userId: firebaseUser.uid,
      photoUrl: userEntity.photoUrl,
    );

    return userEntity;
  }

  @override
  Future<UserEntity> loginWithApple() async {
    try {
      final credential = await _remote.loginWithApple();
      final firebaseUser = credential.user!;

      if (firebaseUser.displayName != null) {
        await _remote.createUserProfile(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          displayName: firebaseUser.displayName!,
          photoUrl: firebaseUser.photoURL,
        );
      }

      final userEntity = _firebaseUserToEntity(firebaseUser);
      _savePushToken(firebaseUser.uid);
      _currentUserNotifier.value = userEntity;

      // Same as Google: keep the user's own active member rows' photo in step
      // with the Auth photo. Photo only, and non-fatal.
      await _syncMemberDisplayInfo(
        userId: firebaseUser.uid,
        photoUrl: userEntity.photoUrl,
      );

      return userEntity;
    } on AuthException catch (e) {
      throw AuthenticationFailure(e.message, e.code);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure(
        'Apple sign in failed: ${e.toString()}',
        code: AuthErrorCodes.unexpected,
      );
    }
  }

  @override
  Future<UserEntity> register(
      String email, String password, String displayName) async {
    try {
      final credential = await _remote.register(email, password);
      final firebaseUser = credential.user!;

      // Create the user profile document in Firestore.
      await _remote.createUserProfile(
        uid: firebaseUser.uid,
        email: email,
        displayName: displayName,
        photoUrl: firebaseUser.photoURL,
      );

      // Update the Firebase Auth display name.
      await firebaseUser.updateDisplayName(displayName);
      await firebaseUser.reload();

      final userEntity = _firebaseUserToEntity(firebaseUser, displayName);
      _savePushToken(firebaseUser.uid);
      _currentUserNotifier.value = userEntity;
      return userEntity;
    } on AuthException catch (e) {
      throw AuthenticationFailure(e.message, e.code);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure(
        'Registration failed: ${e.toString()}',
        code: AuthErrorCodes.unexpected,
      );
    }
  }

  @override
  Future<void> logout() async {
    final uid = _currentUserNotifier.value?.uid;
    await _remote.logout();
    _currentUserNotifier.value = null;
    if (uid != null && uid.isNotEmpty) {
      try {
        await PushNotificationService.instance.clearTokenForUser(uid);
      } catch (_) {
        // Non-critical.
      }
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _remote.forgotPassword(email);
    } on AuthException catch (e) {
      throw AuthenticationFailure(e.message, e.code);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure(
        'Failed to send reset email: ${e.toString()}',
        code: AuthErrorCodes.unexpected,
      );
    }
  }

  @override
  Future<String?> verifyResetCode(String oobCode) async {
    try {
      return await _remote.verifyResetCode(oobCode);
    } on AuthException catch (e) {
      throw AuthenticationFailure(e.message, e.code);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure(
        'Could not verify the reset link: ${e.toString()}',
        code: AuthErrorCodes.unexpected,
      );
    }
  }

  @override
  Future<void> resetPassword({
    required String oobCode,
    required String newPassword,
  }) async {
    try {
      await _remote.confirmPasswordReset(
        oobCode: oobCode,
        newPassword: newPassword,
      );
    } on AuthException catch (e) {
      throw AuthenticationFailure(e.message, e.code);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure(
        'Failed to reset your password: ${e.toString()}',
        code: AuthErrorCodes.unexpected,
      );
    }
  }

  @override
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    final firebaseUser = _remote.currentUser;
    if (firebaseUser == null) {
      throw const FirebaseFailure('Not signed in.');
    }

    try {
      // Update Firebase Auth first so the canonical identity is consistent.
      final newName = displayName?.trim();
      if (newName != null &&
          newName.isNotEmpty &&
          newName != firebaseUser.displayName) {
        await firebaseUser.updateDisplayName(newName);
      }

      if (photoUrl != null && photoUrl != firebaseUser.photoURL) {
        await firebaseUser.updatePhotoURL(photoUrl);
      }

      // Resolve the authoritative post-update values from the profile fields
      // we just pushed through the Auth API — NOT by re-reading `currentUser`.
      // FlutterFire on web caches the signed-in user and only rebuilds that
      // snapshot on an auth-state event, which a profile update does not emit,
      // so a fresh `currentUser` read can still report the OLD values. The
      // values we just wrote are what the server holds, so they drive both the
      // Firestore write and the in-memory notifier below. (uid/email/createdAt
      // are unchanged by a profile edit, so the captured user provides them.)
      final appliedName = (newName != null && newName.isNotEmpty)
          ? newName
          : (firebaseUser.displayName ?? '');
      final appliedPhotoUrl =
          (photoUrl != null) ? photoUrl : firebaseUser.photoURL;

      // Persist to the users/{uid} profile (merge keeps other fields).
      await _remote.createUserProfile(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: appliedName,
        photoUrl: appliedPhotoUrl,
      );

      // Refresh the notifier so the UI reflects the new profile immediately.
      // UserEntity equality is field-based (see UserEntity.==), so a changed
      // photoUrl/displayName on the same uid is a distinct value: the
      // ValueNotifier stores it and notifies listeners.
      _currentUserNotifier.value =
          _firebaseUserToEntity(firebaseUser, appliedName, appliedPhotoUrl);

      // The Auth photo and users/{uid} now hold the new values, but the
      // user's own member rows still hold the old ones — that is exactly how
      // the same person ends up with two different pictures (header vs
      // Members list). Push the applied values onto those rows. Display-only
      // and non-fatal: the profile update has already succeeded.
      await _syncMemberDisplayInfo(
        userId: firebaseUser.uid,
        displayName: appliedName,
        photoUrl: appliedPhotoUrl,
      );
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure('Failed to update profile: ${e.toString()}');
    }
  }

  @override
  Future<String> uploadProfilePhoto({required String localPath}) async {
    final firebaseUser = _remote.currentUser;
    if (firebaseUser == null) {
      throw const FirebaseFailure('Not signed in.');
    }
    return _remote.uploadProfilePhoto(uid: firebaseUser.uid, localPath: localPath);
  }

  /// Pushes display info onto the signed-in user's OWN active membership rows
  /// (all their houses), so the member list, History and Dashboard keep
  /// resolving the same name and photo as the profile.
  ///
  /// NON-FATAL by construction. The membership photo is display-only
  /// bookkeeping, so it must never be able to fail a sign-in or a profile
  /// update: [runMemberProfileSync] converts any failure — offline, denied by
  /// the security rules, a transient Firestore error — into a log line.
  ///
  /// A no-op when no synchronizer was injected, or when the sync would write
  /// nothing (the rows already match, or no new value was supplied): the
  /// planner never blanks a stored photo with an empty one.
  Future<void> _syncMemberDisplayInfo({
    required String userId,
    String? displayName,
    String? photoUrl,
  }) async {
    final sync = _memberDisplayInfoSync;
    if (sync == null || userId.isEmpty) return;

    await runMemberProfileSync(
      () => sync(userId: userId, displayName: displayName, photoUrl: photoUrl),
    );
  }

  /// Registers this device's FCM token so the user receives push notifications.
  Future<void> _savePushToken(String uid) async {
    try {
      await PushNotificationService.instance.saveTokenForUser(uid);
    } catch (_) {
      // Non-critical.
    }
  }

  /// Converts a Firebase [fb_auth.User] to a domain [UserEntity].
  ///
  /// [displayNameOverride] / [photoUrlOverride] let callers supply values that
  /// were just written through the Auth API but may not yet be reflected in
  /// [fb_auth.User.photoURL] (FlutterFire on web only refreshes its user
  /// snapshot on an auth-state event, which a profile update does not emit).
  UserEntity _firebaseUserToEntity(fb_auth.User? firebaseUser,
      [String? displayNameOverride, String? photoUrlOverride]) {
    if (firebaseUser == null) {
      _currentUserNotifier.value = null;
      return UserEntity(
        uid: '',
        email: '',
        displayName: '',
        createdAt: DateTime.now(),
      );
    }

    return UserEntity(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: displayNameOverride ?? firebaseUser.displayName ?? '',
      photoUrl: photoUrlOverride ?? firebaseUser.photoURL,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: firebaseUser.metadata.lastSignInTime,
    );
  }

  /// Handles Firebase auth state changes.
  void _onAuthStateChanged(fb_auth.User? firebaseUser) {
    if (firebaseUser == null) {
      _currentUserNotifier.value = null;
    } else {
      final entity = _firebaseUserToEntity(firebaseUser);
      _currentUserNotifier.value = entity;
      // Covers a session restored after startup. Repeat saves of the same
      // token are skipped by the service.
      _savePushToken(firebaseUser.uid);
    }
  }

  /// Cleans up the auth subscription.
  void dispose() {
    _authSubscription?.cancel();
    _currentUserNotifier.dispose();
  }
}
