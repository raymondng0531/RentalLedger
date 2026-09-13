import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart'
    as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cross_file/cross_file.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/auth_error_codes.dart';

/// Remote data source for authentication.
///
/// Wraps Firebase Auth, Firestore and Storage calls, converting
/// Firebase exceptions into application-specific exceptions.
///
/// Web-only: where the app re-hosts a Firebase action in its own UI (password
/// reset), the reset email must hand the action code to THIS web app instead of
/// Firebase's generic `/__/auth/action` page. `handleCodeInApp: true` makes the
/// email open `webHref` with `mode` + `oobCode` in the query string. The origin
/// is the deployed Firebase Hosting site (the same one `web/index.html` and
/// `cors.json` hard-code). Native keeps Firebase's default (generic page).
const String _webResetContinueUrl =
    'https://rental-ledger-app.web.app/reset-password';

/// Remote data source for authentication.
class AuthRemoteDataSource {
  AuthRemoteDataSource({
    firebase_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  /// Stream of Firebase auth state changes.
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  /// Returns the currently signed-in Firebase user, or `null`.
  firebase_auth.User? get currentUser => _auth.currentUser;

  /// Signs in with email and password.
  Future<firebase_auth.UserCredential> login(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// Signs in with Google.
  Future<firebase_auth.UserCredential> loginWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // Carries a stable code so the UI can recognise a cancellation without
        // pattern-matching on this message — see AuthErrorCodes.
        throw const AuthException(
          'Sign in cancelled.',
          code: AuthErrorCodes.cancelled,
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// Signs in with Apple ID.
  Future<firebase_auth.UserCredential> loginWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthCredential = firebase_auth.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      return await _auth.signInWithCredential(oAuthCredential);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// Creates a new user with email and password.
  Future<firebase_auth.UserCredential> register(
      String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// Creates/updates the user profile document in Firestore.
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      // `merge: true` so a returning social-login user doesn't wipe fields
      // that already exist on their profile (custom display name, fcmToken, etc).
      await _firestore
          .collection(FirestoreConstants.users)
          .doc(uid)
          .set({
            'uid': uid,
            'email': email,
            'displayName': displayName,
            'photoUrl': photoUrl,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AuthRemoteDataSource] Failed to create profile: $e');
      // Non-critical — auth succeeded even if profile write fails.
    }
  }

  /// Uploads a profile photo to Firebase Storage under `profiles/{uid}`.
  ///
  /// Mirrors the receipt-upload pattern so profile photos live in their own
  /// storage path with the same image constraints: on web there is no
  /// filesystem (the picker returns a blob URL), so the bytes are read and
  /// uploaded directly; on native the local file is uploaded unchanged.
  Future<String> uploadProfilePhoto({
    required String uid,
    required String localPath,
  }) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage.ref('profiles/$uid/$fileName');
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      if (kIsWeb) {
        // Web has no filesystem — the picker returns a blob URL, so read the
        // bytes and upload them directly. (Firebase Storage web supports
        // bytes uploads.)
        final bytes = await XFile(localPath).readAsBytes();
        await ref.putData(bytes, metadata);
      } else {
        // Native: unchanged — put the local file directly.
        final file = File(localPath);
        await ref.putFile(file, metadata);
      }

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('[AuthRemoteDataSource] uploadProfilePhoto error: $e');
      throw const AuthException('Failed to upload profile photo.');
    }
  }

  /// Updates the `lastLoginAt` timestamp.
  Future<void> updateLastLogin(String uid) async {
    try {
      await _firestore.collection(FirestoreConstants.users).doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Non-critical.
    }
  }

  /// Signs out the current user (including Google session).
  Future<void> logout() async {
    await _auth.signOut();
    // Also clear the Google sign-in session so the next sign-in
    // shows the account picker instead of auto-logging-in.
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Non-critical — Firebase sign out already happened.
    }
  }

  /// Sends a password reset email.
  Future<void> forgotPassword(String email) async {
    try {
      if (kIsWeb) {
        // In-app (branded) reset: hand the action code to this web app rather
        // than Firebase's generic action page. Native keeps the default flow.
        await _auth.sendPasswordResetEmail(
          email: email,
          actionCodeSettings: firebase_auth.ActionCodeSettings(
            url: _webResetContinueUrl,
            handleCodeInApp: true,
          ),
        );
      } else {
        await _auth.sendPasswordResetEmail(email: email);
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// Verifies a password-reset action code against Firebase.
  ///
  /// Returns the email the code was issued for on success. Throws
  /// [AuthException] when the code is invalid or has expired, so the reset UI
  /// can show a "link problem" state instead of a fake form.
  Future<String?> verifyResetCode(String oobCode) async {
    try {
      return await _auth.verifyPasswordResetCode(oobCode);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// Completes a password reset for a verified [oobCode].
  ///
  /// Performs the real Firebase reset (never a client-side-only "fake"
  /// reset). Throws [AuthException] (e.g. weak password, already-used or
  /// expired code) on failure.
  Future<void> confirmPasswordReset({
    required String oobCode,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(code: oobCode, newPassword: newPassword);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// Maps Firebase Auth exceptions to app exceptions.
  ///
  /// Each case carries an `AuthErrorCodes` [code] alongside its message. The
  /// code is the contract the UI branches and displays on; the message is only
  /// an English fallback for a caller that has no localization to hand (a test,
  /// a log line). Firebase's own `e.message` is deliberately never surfaced —
  /// it is untranslated SDK prose.
  AuthException _mapAuthException(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return const AuthException(
          'Invalid email address.',
          code: AuthErrorCodes.invalidEmail,
        );
      case 'user-disabled':
        return const AuthException(
          'This account has been disabled.',
          code: AuthErrorCodes.userDisabled,
        );
      case 'user-not-found':
        return const AuthException(
          'No account found with this email.',
          code: AuthErrorCodes.userNotFound,
        );
      case 'wrong-password':
        return const AuthException(
          'Invalid email or password.',
          code: AuthErrorCodes.wrongPassword,
        );
      case 'invalid-credential':
        return const AuthException(
          'Invalid email or password.',
          code: AuthErrorCodes.invalidCredential,
        );
      case 'email-already-in-use':
        return const AuthException(
          'An account already exists with this email.',
          code: AuthErrorCodes.emailAlreadyInUse,
        );
      case 'operation-not-allowed':
        return const AuthException(
          'Email/password sign-in is not enabled.',
          code: AuthErrorCodes.operationNotAllowed,
        );
      case 'too-many-requests':
        return const AuthException(
          'Too many attempts. Please try again later.',
          code: AuthErrorCodes.tooManyRequests,
        );
      case 'weak-password':
        return const AuthException(
          'Password is too weak.',
          code: AuthErrorCodes.weakPassword,
        );
      case 'invalid-action-code':
        return const AuthException(
          'This reset link is invalid. Please request a new one.',
          code: AuthErrorCodes.invalidActionCode,
        );
      case 'expired-action-code':
        return const AuthException(
          'This reset link has expired. Please request a new one.',
          code: AuthErrorCodes.expiredActionCode,
        );
      case 'network-request-failed':
        return const AuthException(
          'Network error. Please check your connection.',
          code: AuthErrorCodes.networkRequestFailed,
        );
      case 'requires-recent-login':
        return const AuthException(
          'Please sign in again to continue.',
          code: AuthErrorCodes.requiresRecentLogin,
        );
      default:
        // Nothing mapped this code — report it as unexpected so the UI shows
        // its generic sentence instead of raw SDK text.
        return const AuthException(
          'An authentication error occurred.',
          code: AuthErrorCodes.unexpected,
        );
    }
  }
}
