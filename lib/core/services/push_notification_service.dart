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
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance =
      PushNotificationService._();

  final _messaging = FirebaseMessaging.instance;

  /// The current device's FCM token, if granted.
  String? _deviceToken;

  /// The userId the last token was saved for — used to persist rotated tokens.
  String? _savedForUserId;

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

      // Get the device token.
      _deviceToken = await _messaging.getToken();
      debugPrint('[PushNotificationService] Token: $_deviceToken');

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
    } catch (e) {
      debugPrint('[PushNotificationService] Init error: $e');
    }
  }

  /// Saves the current FCM token to the user's profile in Firestore.
  Future<void> saveTokenForUser(String userId) async {
    if (_deviceToken == null) return;
    _savedForUserId = userId;
    await _saveToken(userId, _deviceToken!);
  }

  Future<void> _saveToken(String userId, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreConstants.users)
          .doc(userId)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PushNotificationService] Save token error: $e');
    }
  }

  /// Deletes the FCM token from the user profile (on sign out).
  Future<void> clearTokenForUser(String userId) async {
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
