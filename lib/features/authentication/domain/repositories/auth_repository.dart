import 'package:flutter/foundation.dart';

import '../entities/user_entity.dart';

/// Abstract repository for authentication operations.
///
/// Defines the contract that the data layer must implement.
/// The presentation layer communicates only through this interface.
abstract class AuthRepository {
  /// A [ValueNotifier] that emits the current user whenever auth state changes.
  /// Used by GoRouter's `refreshListenable` to trigger redirect re-evaluation.
  ValueNotifier<UserEntity?> get currentUserNotifier;

  /// Returns the currently authenticated user, or `null`.
  UserEntity? get currentUser;

  /// Stream of auth state changes — fires `null` on logout.
  Stream<UserEntity?> authStateChanges();

  /// Signs in with email and password.
  ///
  /// Returns the authenticated [UserEntity] on success.
  /// Throws [AuthException] on failure.
  Future<UserEntity> login(String email, String password);

  /// Signs in with Google.
  Future<UserEntity> loginWithGoogle();

  /// Signs in with Apple ID.
  Future<UserEntity> loginWithApple();

  /// Creates a new account with email, password, and display name.
  ///
  /// Returns the newly created [UserEntity] on success.
  /// Throws [AuthException] if the email is already registered.
  Future<UserEntity> register(String email, String password, String displayName);

  /// Signs out the current user.
  Future<void> logout();

  /// Sends a password reset email.
  Future<void> forgotPassword(String email);

  /// Updates the current user's profile (display name / photo) across Firebase
  /// Auth and the `users/{uid}` profile, and refreshes the auth notifier so
  /// every page sees the change immediately. Pass `null` to leave a field as-is.
  Future<void> updateProfile({String? displayName, String? photoUrl});

  /// Uploads a profile photo to Firebase Storage (`profiles/{uid}`) and
  /// returns its download URL.
  Future<String> uploadProfilePhoto({required String localPath});
}
