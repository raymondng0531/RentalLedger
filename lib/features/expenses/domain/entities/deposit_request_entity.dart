/// A deposit a member submitted for themselves, awaiting the Treasurer.
///
/// A request is deliberately NOT a transaction. Transactions are immutable and
/// the Central Account balance is the sum of them, so a deposit that has not
/// been confirmed yet must not exist in the ledger at all. Only when the
/// Treasurer approves the request is ONE Deposit transaction written — in the
/// same commit that flips the request to Approved — and that transaction's id
/// is this request's [requestId] (the approval's idempotency key).
///
/// Statuses: Pending → Approved | Rejected. A member may cancel (delete) their
/// own Pending request; reviewed requests are final.
class DepositRequestEntity {
  const DepositRequestEntity({
    required this.requestId,
    required this.houseId,
    required this.amount,
    required this.paidByUserId,
    required this.submittedBy,
    this.paymentMethod,
    this.periodLabel,
    this.purpose,
    this.notes,
    this.receiptUrl,
    this.status = statusPending,
    this.rejectReason,
    this.reviewedBy,
    this.reviewedAt,
    this.transactionId,
    required this.createdAt,
  });

  /// Raw stored status values (mirrored by `FirestoreConstants` and asserted
  /// by the security rules).
  static const String statusPending = 'Pending';
  static const String statusApproved = 'Approved';
  static const String statusRejected = 'Rejected';

  final String requestId;
  final String houseId;

  /// Positive amount the member says they paid into the Central Account.
  final double amount;

  /// The member who physically paid the money in. For a member-submitted
  /// request this is always the submitter themselves.
  final String paidByUserId;

  /// The member who submitted the request.
  final String submittedBy;

  /// How the money moved (e.g. 'Cash', 'Bank Transfer', 'e-Wallet').
  final String? paymentMethod;

  /// The month/period the contribution covers, e.g. `2026-09`.
  final String? periodLabel;

  /// Structured purpose, e.g. 'Monthly Rental'. Stored verbatim.
  final String? purpose;

  final String? notes;

  /// Proof image download URL. Required on submission.
  final String? receiptUrl;

  final String status;

  /// The Treasurer's reason when the request was rejected.
  final String? rejectReason;

  /// The Treasurer who approved or rejected the request.
  final String? reviewedBy;
  final DateTime? reviewedAt;

  /// The Deposit transaction written on approval (equals [requestId]).
  final String? transactionId;

  final DateTime createdAt;

  bool get isPending => status == statusPending;
  bool get isApproved => status == statusApproved;
  bool get isRejected => status == statusRejected;
}
