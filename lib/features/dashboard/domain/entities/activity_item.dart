/// A single item in the recent activity feed.
class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.date,
    this.subtitle,
    this.iconColor,
    this.status,
    this.categoryId,
    this.paymentSource,
  });

  final String id;

  /// Transaction type: 'deposit', 'expense', 'reimbursement', 'payment'.
  final String type;

  /// Display title (e.g., "Laundry Detergent").
  final String title;

  /// Optional subtitle (e.g., "paid by John").
  final String? subtitle;

  /// Monetary amount.
  final double amount;

  /// When the activity occurred.
  final DateTime date;

  /// Optional icon tint for the activity.
  final int? iconColor;

  /// Optional status string for display.
  final String? status;

  /// Category id (expense items) — drives the category icon + chip.
  final String? categoryId;

  /// Payment source ('personal' | 'central') — drives the method chip.
  final String? paymentSource;
}
