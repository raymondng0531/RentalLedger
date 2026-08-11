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
  });

  final String transactionId;
  final String houseId;
  final String? expenseId;
  final String type; // Deposit | Reimbursement | Direct Payment | Adjustment
  final double amount;
  final String performedBy;
  final String? notes;
  final DateTime createdAt;

  bool get isDeposit => type == 'Deposit';
  bool get isReimbursement => type == 'Reimbursement';
  bool get isDirectPayment => type == 'Direct Payment';
  bool get isAdjustment => type == 'Adjustment';

  /// Positive amount means money in, negative means money out.
  bool get isInflow => isDeposit || isAdjustment;
  bool get isOutflow => isReimbursement || isDirectPayment;
}
