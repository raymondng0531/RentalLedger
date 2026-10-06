/// Pure decision helpers for member-submitted deposit requests.
///
/// Same split as `financial_guards.dart`: the data source performs the read
/// and the write inside ONE Firestore transaction (so the platform serialises
/// two Treasurers racing the same request), and these functions decide whether
/// the state it read is acceptable. Kept pure so the policy is unit-testable
/// without a Firestore harness — the data source calls these exact functions.
library;

import '../entities/deposit_request_entity.dart';

/// Why reviewing (approving or rejecting) a request currently in
/// [currentStatus] is refused, or null when it may be reviewed.
///
/// Only a Pending request is reviewable. A second Approve — a double tap, a
/// stale tab, a retry after a timeout — reads Approved and is refused instead
/// of writing a second Deposit.
String? depositRequestReviewRefusal({required String currentStatus}) {
  if (currentStatus == DepositRequestEntity.statusPending) return null;
  return 'This deposit request has already been reviewed — its current status '
      'is "$currentStatus". Refresh to see it.';
}

/// Why [userId] may not cancel a request submitted by [submittedBy] that is
/// currently in [currentStatus], or null when the cancellation is allowed.
///
/// A member may withdraw only their OWN request, and only while it is still
/// Pending — once reviewed it is part of the house's record.
String? depositRequestCancelRefusal({
  required String userId,
  required String submittedBy,
  required String currentStatus,
}) {
  if (submittedBy != userId) {
    return 'You can only cancel your own deposit request.';
  }
  if (currentStatus != DepositRequestEntity.statusPending) {
    return 'Only pending deposit requests can be cancelled.';
  }
  return null;
}
