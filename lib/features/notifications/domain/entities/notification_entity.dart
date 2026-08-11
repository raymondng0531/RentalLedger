/// A system notification for a user.
///
/// Types: Expense Submitted, Expense Approved, Expense Rejected,
///        Payment Completed, Deposit Recorded
class NotificationEntity {
  const NotificationEntity({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    this.relatedId,
    required this.createdAt,
  });

  final String notificationId;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final String? relatedId;
  final DateTime createdAt;

  NotificationEntity copyWith({bool? isRead}) {
    return NotificationEntity(
      notificationId: notificationId,
      userId: userId,
      title: title,
      body: body,
      type: type,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId,
      createdAt: createdAt,
    );
  }
}
