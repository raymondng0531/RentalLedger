/// Pure decision helpers for the money-movement guards.
///
/// Every financial action in this app is a two-phase operation: the client
/// READS the current state — an expense's status, the Central Account balance,
/// a bill's due date — and then WRITES the transition. Without a precondition
/// on that read, two clients racing (a double-tapped Approve, a stale browser
/// tab still showing "Mark Paid", a retry after a timeout) can both pass the
/// read and both write, producing a second review, a second reimbursement, or
/// a negative balance.
///
/// `expense_remote_datasource.dart` now performs the read and the write inside
/// ONE Firestore transaction, so the platform aborts whichever writer loses the
/// race. What the transaction cannot decide on its own is *whether* a given
/// state is acceptable — that is business policy, and it lives here as pure
/// functions so the exact rules are unit-testable without a Firestore harness.
///
/// The data source calls these same functions inside its transactions, so the
/// tests exercise the production decisions rather than a copy of them. The
/// atomicity itself (that Firestore really does serialise the two writers)
/// cannot be proven by a unit test — see the Phase 3 report.
library;

import '../../../../core/utils/currency_utils.dart';

// ───── Expense workflow statuses ─────
// Mirrors the raw values stored in Firestore and asserted by the security
// rules; kept as constants here so the guards below read as policy rather than
// as string comparisons.

/// Submitted by a member, awaiting the Treasurer's review.
const String expenseStatusPending = 'pending';

/// Reviewed and accepted by the Treasurer; awaiting reimbursement.
const String expenseStatusApproved = 'approved';

/// Reviewed and declined by the Treasurer. Terminal.
const String expenseStatusRejected = 'rejected';

/// Reimbursed from the Central Account. Terminal.
const String expenseStatusPaid = 'paid';

/// The status each guarded transition must find the expense in.
///
/// * Approve / Reject are review actions: only a `pending` claim is reviewable.
/// * Reimburse (Mark Paid) is a payout: only an `approved` claim has been
///   cleared for payment.
///
/// A transition missing from this map is not guarded by a status precondition.
const Map<String, String> expenseTransitionSourceStatus = {
  expenseStatusApproved: expenseStatusPending,
  expenseStatusRejected: expenseStatusPending,
  expenseStatusPaid: expenseStatusApproved,
};

/// Why the expense transition into [targetStatus] is refused for an expense
/// currently in [currentStatus], or null when the transition is allowed.
///
/// This is the check that makes "A second concurrent request must fail
/// cleanly" true for approve / reject / reimburse: the second request reads a
/// status its target transition does not accept, and is refused instead of
/// writing the same transition twice.
String? expenseTransitionRefusal({
  required String currentStatus,
  required String targetStatus,
}) {
  final requiredSource = expenseTransitionSourceStatus[targetStatus];
  // Not a guarded transition (e.g. a member editing their own pending claim).
  if (requiredSource == null) return null;
  if (currentStatus == requiredSource) return null;

  if (targetStatus == expenseStatusPaid) {
    return 'This expense is not awaiting reimbursement — its current status is '
        '"$currentStatus". Refresh to see it.';
  }
  return 'This expense has already been reviewed — its current status is '
      '"$currentStatus". Refresh to see it.';
}

/// Why an outflow of [amount] is refused against [balance], or null when the
/// Central Account can cover it.
///
/// Per `docs/05_BUSINESS_RULES.md` ("Balance Calculation") the balance is the
/// sum of transaction history and the app must never let it go negative, so an
/// unaffordable reimbursement or direct payment is refused outright rather than
/// allowed to overdraw.
///
/// [amount] is the magnitude of the outflow; the sign is ignored, so callers
/// may pass either an expense amount or a signed transaction amount.
String? insufficientBalanceRefusal({
  required double balance,
  required double amount,
}) {
  final outflow = amount.abs();
  if (balance - outflow >= 0) return null;
  return 'Insufficient balance. This payment of ${CurrencyUtils.format(outflow)} '
      'exceeds the Central Account balance of ${CurrencyUtils.format(balance)}.';
}

/// Why marking a bill paid would record a SECOND Direct Payment for a period
/// that was already paid, or null when this is the first payment of the period.
///
/// A bill is a template that is paid once per due date: a one-off bill flips
/// `isPaid` to true, a recurring bill rolls its due date forward to the next
/// month. Either way, a submission carrying a due date the template has already
/// moved past is a duplicate of one that already succeeded — a double tap must
/// not buy the same month twice.
///
/// A null [storedDueDate] (a legacy bill stored without one) cannot be compared,
/// so the payment is allowed rather than blocked on missing data.
String? duplicateBillPaymentRefusal({
  required bool isPaid,
  required DateTime? storedDueDate,
  required DateTime expectedDueDate,
}) {
  if (isPaid) {
    return 'This bill has already been marked paid. Refresh to see its '
        'current state.';
  }
  if (storedDueDate != null && !_isSameCalendarDay(storedDueDate, expectedDueDate)) {
    return 'This bill has already been paid for that period and moved on to its '
        'next due date. Refresh to see its current state.';
  }
  return null;
}

/// Compares dates by calendar day, not by instant.
///
/// The due date crosses Firestore as a `Timestamp` (microsecond precision) and
/// comes back into the UI as a `DateTime`, so an exact equality test would be
/// brittle. A recurring bill that has been paid rolls forward by a whole month,
/// which a day-level comparison detects just as reliably.
bool _isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
