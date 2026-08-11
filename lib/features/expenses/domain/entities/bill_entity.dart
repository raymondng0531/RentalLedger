/// A recurring bill or payment reminder for the house.
///
/// Used on the Dashboard's "Upcoming Bills" section.
/// Bills have a specific due date. Amount is optional — it can be used
/// purely as a reminder (e.g., for utilities payments).
class BillEntity {
  const BillEntity({
    required this.billId,
    required this.houseId,
    required this.title,
    this.amount,
    required this.dueDate,
    this.categoryId = 'utilities',
    this.isActive = true,
    this.isRecurring = false,
    this.reminderEnabled = false,
    this.isPaid = false,
    required this.createdAt,
  });

  final String billId;
  final String houseId;
  final String title;

  /// Amount due. Null when used as a reminder without a set amount.
  final double? amount;

  /// Next due date.
  final DateTime dueDate;

  final String categoryId;
  final bool isActive;

  /// Repeat every month and auto-create the next bill.
  final bool isRecurring;

  /// Whether a reminder is set for this bill.
  final bool reminderEnabled;

  /// Whether the current month's bill has been paid.
  final bool isPaid;

  final DateTime createdAt;

  bool get hasAmount => amount != null;

  /// Number of days until the due date (negative = overdue).
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  bool get isOverdue => daysLeft < 0;
  bool get isDueToday => daysLeft == 0;

  /// Whether the bill is due within [days] from today.
  bool isDueWithin(int days, {DateTime? from}) {
    return daysLeft >= 0 && daysLeft <= days;
  }

  /// A friendly countdown label: "Due Today", "Tomorrow",
  /// "3 days left", "7 days left", or "Overdue by 2 days".
  String get countdownLabel {
    if (isOverdue) {
      final d = daysLeft.abs();
      return d == 1 ? 'Overdue by 1 day' : 'Overdue by $d days';
    }
    if (isDueToday) return 'Due Today';
    if (daysLeft == 1) return 'Tomorrow';
    return '$daysLeft days left';
  }

  /// Countdown urgency: red for due/overdue, orange for 3-7 days,
  /// green for more than 7 days.
  BillUrgency get urgency {
    if (isOverdue || isDueToday) return BillUrgency.red;
    if (daysLeft <= 7) return BillUrgency.orange;
    return BillUrgency.green;
  }

  BillEntity copyWith({
    double? amount,
    bool clearAmount = false,
    DateTime? dueDate,
    bool? isActive,
    bool? isRecurring,
    bool? reminderEnabled,
    bool? isPaid,
  }) {
    return BillEntity(
      billId: billId,
      houseId: houseId,
      title: title,
      amount: clearAmount ? null : (amount ?? this.amount),
      dueDate: dueDate ?? this.dueDate,
      categoryId: categoryId,
      isActive: isActive ?? this.isActive,
      isRecurring: isRecurring ?? this.isRecurring,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      isPaid: isPaid ?? this.isPaid,
      createdAt: createdAt,
    );
  }
}

/// Visual urgency of a bill's countdown.
enum BillUrgency { green, orange, red }
