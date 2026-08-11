import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../models/notification_model.dart';

/// Remote data source for notifications.
class NotificationRemoteDataSource {
  NotificationRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  /// Creates a notification for a user.
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
  }) async {
    try {
      final id = _uuid.v4();
      final notif = NotificationModel(
        notificationId: id,
        userId: userId,
        title: title,
        body: body,
        type: type,
        relatedId: relatedId,
        createdAt: DateTime.now(),
      );
      await _firestore
          .collection(FirestoreConstants.notifications)
          .doc(id)
          .set(notif.toMap());
    } catch (e) {
      debugPrint('[NotificationDataSource] createNotification error: $e');
      // Notifications are non-critical — don't throw.
    }
  }

  /// Fetches notifications for a user, newest first.
  Future<List<NotificationModel>> getNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreConstants.notifications)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[NotificationDataSource] getNotifications error: $e');
      return [];
    }
  }

  /// Stream of notifications for real-time updates.
  Stream<List<NotificationModel>> notificationsStream(String userId) {
    return _firestore
        .collection(FirestoreConstants.notifications)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NotificationModel.fromFirestore(doc)).toList());
  }

  /// Marks a notification as read.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(FirestoreConstants.notifications)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('[NotificationDataSource] markAsRead error: $e');
    }
  }

  /// Marks all notifications as read for a user.
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreConstants.notifications)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[NotificationDataSource] markAllAsRead error: $e');
    }
  }

  /// Returns the count of unread notifications.
  Future<int> unreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreConstants.notifications)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('[NotificationDataSource] unreadCount error: $e');
      return 0;
    }
  }
}
