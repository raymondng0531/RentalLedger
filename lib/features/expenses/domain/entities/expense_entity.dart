/// Domain-level expense entity.
///
/// Status flow: pending → approved → paid
///              → rejected (terminal)
/// Members edit/delete only while pending.
class ExpenseEntity {
  const ExpenseEntity({
    required this.expenseId,
    required this.houseId,
    required this.purchasedBy,
    this.approvedBy,
    this.reimbursedBy,
    required this.title,
    this.description,
    required this.categoryId,
    required this.amount,
    this.receiptUrl,
    required this.paymentSource,
    this.status = 'pending',
    this.rejectReason,
    required this.createdAt,
    this.approvedAt,
    this.paidAt,
    this.updatedAt,
    this.displayName,
  });

  final String expenseId;
  final String houseId;
  final String purchasedBy;
  final String? approvedBy;
  final String? reimbursedBy;
  final String title;
  final String? description;
  final String categoryId;
  final double amount;
  final String? receiptUrl;
  final String paymentSource; // 'personal' | 'central'
  final String status; // 'pending' | 'approved' | 'rejected' | 'paid'
  final String? rejectReason;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final DateTime? updatedAt;

  /// Display name of the purchaser (joined from user data).
  final String? displayName;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isPaid => status == 'paid';
  bool get isRejected => status == 'rejected';
  bool get isPersonal => paymentSource == 'personal';
  bool get isCentral => paymentSource == 'central';
  bool get isEditable => isPending;
  bool get isDeletable => isPending;

  ExpenseEntity copyWith({
    String? expenseId,
    String? houseId,
    String? purchasedBy,
    String? approvedBy,
    String? reimbursedBy,
    String? title,
    String? description,
    String? categoryId,
    double? amount,
    String? receiptUrl,
    String? paymentSource,
    String? status,
    String? rejectReason,
    DateTime? createdAt,
    DateTime? approvedAt,
    DateTime? paidAt,
    DateTime? updatedAt,
    String? displayName,
  }) {
    return ExpenseEntity(
      expenseId: expenseId ?? this.expenseId,
      houseId: houseId ?? this.houseId,
      purchasedBy: purchasedBy ?? this.purchasedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      reimbursedBy: reimbursedBy ?? this.reimbursedBy,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      paymentSource: paymentSource ?? this.paymentSource,
      status: status ?? this.status,
      rejectReason: rejectReason ?? this.rejectReason,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      paidAt: paidAt ?? this.paidAt,
      updatedAt: updatedAt ?? this.updatedAt,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseEntity &&
          runtimeType == other.runtimeType &&
          expenseId == other.expenseId;

  @override
  int get hashCode => expenseId.hashCode;
}
