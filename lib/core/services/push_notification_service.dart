import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/firestore_constants.dart';

/// Firebase Cloud Messaging service.
///
/// Handles:
/// - Notification permission requests
/// - FCM token retrieval + storage on the user profile
/// - Foreground message display
///
/// On web, a token is only issued once the browser grants notification
/// permission. Some browsers (Safari on iPhone/iPad, installed to the Home
/// Screen) only show the permission prompt from a user tap, so the startup
/// request in [initialize] can come back without a token; Settings then calls
/// [enableFromUserGesture] from a button.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance =
      PushNotificationService._();

  final _messaging = FirebaseMessaging.instance;

  /// The current device's FCM token, if granted.
  String? _deviceToken;

  /// The userId the last token was saved for — used to persist rotated tokens.
  String? _savedForUserId;

  /// The (userId, token) pair last written, so a repeated save is skipped.
  String? _lastWrittenKey;

  bool _listenersAttached = false;

  /// Optional Web Push certificate public key (Firebase Console > Project
  /// settings > Cloud Messaging > Web Push certificates), supplied with
  /// `--dart-define=FCM_VAPID_KEY=...`. When empty the Firebase JS SDK falls
  /// back to its built-in default key.
  static const String _vapidKey = String.fromEnvironment('FCM_VAPID_KEY');

  String? get deviceToken => _deviceToken;

  /// Requests notification permission and registers the device.
  Future<void> initialize() async {
    try {
      // Request permission (iOS/web). Android 13+ needs it too.
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[PushNotificationService] Permission denied.');
        return;
      }

      await _fetchTokenAndListen();
    } catch (e) {
      debugPrint('[PushNotificationService] Init error: $e');
    }
  }

  /// Asks for notification permission from a user tap (required by Safari on
  /// iPhone/iPad) and registers this device for the signed-in user.
  ///
  /// Returns the resulting permission status.
  Future<AuthorizationStatus> enableFromUserGesture() async {
    try {
      // Defaults are alert/badge/sound: true.
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _fetchTokenAndListen();
      }
      return settings.authorizationStatus;
    } catch (e) {
      debugPrint('[PushNotificationService] Enable error: $e');
      return AuthorizationStatus.notDetermined;
    }
  }

  /// The current notification permission, without prompting.
  Future<AuthorizationStatus> permissionStatus() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return settings.authorizationStatus;
    } catch (e) {
      debugPrint('[PushNotificationService] Status error: $e');
      return AuthorizationStatus.notDetermined;
    }
  }

  Future<void> _fetchTokenAndListen() async {
    // Get the device token.
    _deviceToken = await _messaging.getToken(
      vapidKey: kIsWeb && _vapidKey.isNotEmpty ? _vapidKey : null,
    );
    debugPrint('[PushNotificationService] Token: $_deviceToken');

    // A user may already be signed in (restored session, or permission
    // granted after sign-in) — store the token now that it exists.
    final uid = _savedForUserId;
    final token = _deviceToken;
    if (uid != null && uid.isNotEmpty && token != null) {
      await _saveToken(uid, token);
    }

    if (_listenersAttached) return;
    _listenersAttached = true;

    // Refresh token when it changes — and persist it so the stored token
    // on the user's profile never goes stale (else push stops arriving).
    _messaging.onTokenRefresh.listen((token) {
      _deviceToken = token;
      final uid = _savedForUserId;
      if (uid != null && uid.isNotEmpty) {
        _saveToken(uid, token);
      }
    });

    // Handle foreground messages (shown as an overlay elsewhere).
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[PushNotificationService] Foreground: '
          '${message.notification?.title}');
    });
  }

  /// Saves the current FCM token to the user's profile in Firestore.
  ///
  /// Remembers [userId] even when no token exists yet, so a token issued
  /// later is saved for them.
  Future<void> saveTokenForUser(String userId) async {
    _savedForUserId = userId;
    if (_deviceToken == null) return;
    await _saveToken(userId, _deviceToken!);
  }

  Future<void> _saveToken(String userId, String token) async {
    final key = '$userId|$token';
    if (key == _lastWrittenKey) return;
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreConstants.users)
          .doc(userId)
          .set({'fcmToken': token}, SetOptions(merge: true));
      _lastWrittenKey = key;
    } catch (e) {
      debugPrint('[PushNotificationService] Save token error: $e');
    }
  }

  /// Deletes the FCM token from the user profile (on sign out).
  Future<void> clearTokenForUser(String userId) async {
    _savedForUserId = null;
    _lastWrittenKey = null;
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreConstants.users)
          .doc(userId)
          .update({'fcmToken': FieldValue.delete()});
    } catch (e) {
      debugPrint('[PushNotificationService] Clear token error: $e');
    }
  }
}
