import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.notificationId,
    required super.userId,
    required super.title,
    required super.body,
    required super.type,
    super.isRead,
    super.relatedId,
    required super.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel.fromMap(data, doc.id);
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    return NotificationModel(
      notificationId: docId,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? '',
      isRead: map['isRead'] as bool? ?? false,
      relatedId: map['relatedId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'relatedId': relatedId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  NotificationEntity toEntity() => this;
}
