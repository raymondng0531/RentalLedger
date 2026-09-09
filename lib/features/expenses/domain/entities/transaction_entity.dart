/// A financial transaction that affects the Central Account balance.
///
/// Types: Deposit, Reimbursement, Direct Payment, Adjustment
/// Transactions are immutable — corrections use a new Adjustment transaction.
class TransactionEntity {
  const TransactionEntity({
    required this.transactionId,
    required this.houseId,
    this.expenseId,
    required this.type,
    required this.amount,
    required this.performedBy,
    this.notes,
    required this.createdAt,
    // ── Proof / attribution (all optional for backward compatibility) ──
    this.receiptUrl,
    this.paidByUserId,
    this.paymentMethod,
    this.periodLabel,
    this.purpose,
    this.categoryId,
  });

  final String transactionId;
  final String houseId;
  final String? expenseId;
  final String type; // Deposit | Reimbursement | Direct Payment | Adjustment
  final double amount;
  final String performedBy;

  /// Free-form notes / display title (e.g. deposit notes, direct-payment title,
  /// or `Bill: <title>` for bill payments).
  final String? notes;
  final DateTime createdAt;

  /// Receipt/proof image download URL for the money movement. Every actual
  /// money movement carries its own proof; null on legacy transactions.
  final String? receiptUrl;

  /// The member who actually paid the money in (deposits / contributions).
  /// The recorder is [performedBy] (the Treasurer) — this is who PHYSICALLY
  /// provided the funds. Null for money-out and legacy transactions.
  final String? paidByUserId;

  /// How the money moved (e.g. 'Cash', 'Bank Transfer', 'e-Wallet').
  final String? paymentMethod;

  /// The month/period a payment or contribution covers, e.g. `2026-09`.
  final String? periodLabel;

  /// Structured purpose, e.g. 'Monthly Rental' / 'House Contribution' /
  /// 'General Top-up'. May equal [notes] for human-readable display.
  final String? purpose;

  /// Category (Direct Payments only, e.g. a paid utility bill). Null for
  /// deposits, reimbursements, and legacy transactions.
  final String? categoryId;

  bool get isDeposit => type == 'Deposit';
  bool get isReimbursement => type == 'Reimbursement';
  bool get isDirectPayment => type == 'Direct Payment';
  bool get isAdjustment => type == 'Adjustment';

  /// Positive amount means money in, negative means money out.
  bool get isInflow => isDeposit || isAdjustment;
  bool get isOutflow => isReimbursement || isDirectPayment;
}
