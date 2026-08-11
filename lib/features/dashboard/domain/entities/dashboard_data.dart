import 'activity_item.dart';
import 'monthly_summary.dart';

/// Complete dashboard data — one snapshot fetched from Firestore.
class DashboardData {
  const DashboardData({
    this.balance = 0.0,
    this.houseName = '',
    this.monthly = const MonthlySummary(),
    this.recentActivity = const [],
    this.pendingItems = const [],
    this.currency = 'MYR',
  });

  /// Central account balance.
  final double balance;

  /// House name.
  final String houseName;

  /// Monthly financial summary.
  final MonthlySummary monthly;

  /// Recent transaction activity.
  final List<ActivityItem> recentActivity;

  /// Open expense claims (submitted + approved) still waiting on the
  /// Treasurer. The single source of truth for the Pending summary card —
  /// [MonthlySummary.pendingReimbursements] is derived from this same list, so
  /// the card and the Pending Items section always agree.
  final List<ActivityItem> pendingItems;

  /// Currency code.
  final String currency;

  /// Whether there is any data to display.
  bool get isEmpty => recentActivity.isEmpty && monthly.pendingCount == 0;
}
