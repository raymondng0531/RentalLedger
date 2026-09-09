import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Implementation of [AuthRepository] backed by Firebase Auth + Firestore.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthRemoteDataSource remoteDataSource})
      : _remote = remoteDataSource {
    // Listen to Firebase auth state and update the notifier.
    _authSubscription = _remote.authStateChanges.listen(_onAuthStateChanged);

    // Check if there's already a signed-in user.
    final existingUser = _remote.currentUser;
    if (existingUser != null) {
      _currentUserNotifier.value = _firebaseUserToEntity(existingUser);
    }
  }

  final AuthRemoteDataSource _remote;
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
      throw AuthenticationFailure(e.message);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure('Login failed: ${e.toString()}');
    }
  }

  @override
  Future<UserEntity> loginWithGoogle() async {
    try {
      final credential = await _remote.loginWithGoogle();
      final firebaseUser = credential.user!;

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
      return userEntity;
    } on AuthException catch (e) {
      throw AuthenticationFailure(e.message);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure('Google sign in failed: ${e.toString()}');
    }
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
      return userEntity;
    } on AuthException catch (e) {
      throw AuthenticationFailure(e.message);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure('Apple sign in failed: ${e.toString()}');
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
      throw AuthenticationFailure(e.message);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure('Registration failed: ${e.toString()}');
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
      throw AuthenticationFailure(e.message);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure('Failed to send reset email: ${e.toString()}');
    }
  }

  @override
  Future<String?> verifyResetCode(String oobCode) async {
    try {
      return await _remote.verifyResetCode(oobCode);
    } on AuthException catch (e) {
      throw AuthenticationFailure(e.message);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure(
          'Could not verify the reset link: ${e.toString()}');
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
      throw AuthenticationFailure(e.message);
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseFailure {
      rethrow;
    } catch (e) {
      throw FirebaseFailure('Failed to reset your password: ${e.toString()}');
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
    }
  }

  /// Cleans up the auth subscription.
  void dispose() {
    _authSubscription?.cancel();
    _currentUserNotifier.dispose();
  }
}
