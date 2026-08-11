/// Aggregated monthly financial summary for the dashboard.
///
/// Money In / Money Out follow the same rules as the Reports page: split
/// transactions by amount sign, so direct/bill payments count toward Money Out.
class MonthlySummary {
  const MonthlySummary({
    this.moneyIn = 0.0,
    this.moneyOut = 0.0,
    this.pendingReimbursements = 0.0,
    this.pendingCount = 0,
  });

  /// Every positive transaction this month (deposits + positive adjustments).
  final double moneyIn;

  /// Every negative transaction this month (absolute value): reimbursements,
  /// direct payments, bill payments, negative adjustments.
  final double moneyOut;

  /// Total amount pending reimbursement.
  final double pendingReimbursements;

  /// Number of pending expense claims.
  final int pendingCount;

  /// Net cash flow = money in − money out.
  double get netFlow => moneyIn - moneyOut;

  /// Whether there are any pending reimbursements.
  bool get hasPending => pendingCount > 0;
}
