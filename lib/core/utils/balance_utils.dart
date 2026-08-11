/// The Central Account Balance is the sum of every transaction's amount.
///
/// Deposits add to it, Reimbursements and Direct Payments subtract, and
/// Adjustments can do either (their signed amount is used as-is).
///
/// This is the single source of truth for the balance. Both the Dashboard's
/// "Central Account Balance" and the Reports page's "Current Balance" call
/// this same function over the same transactions collection, so the two
/// values can never diverge.
double computeCentralBalance(Iterable<double> amounts) {
  return amounts.fold(0, (sum, amount) => sum + amount);
}
