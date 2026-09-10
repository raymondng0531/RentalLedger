import '../../domain/entities/bill_entity.dart';
import '../models/bill_model.dart';
import '../models/transaction_model.dart';

/// The money-movement surface of the expense data source.
///
/// Financial actions (record a deposit / direct payment / bill payment) each
/// write exactly ONE transaction document via these methods, and any attached
/// proof is uploaded with [uploadReceipt] BEFORE the ledger write — a failed
/// upload must never leave a transaction behind.
///
/// Exposing this narrow contract (instead of the full [ExpenseRemoteDataSource]
/// concrete class) lets the presentation notifiers be unit-tested with a fake,
/// matching how repository interfaces are faked elsewhere in the suite.
abstract interface class ExpenseLedgerDataSource {
  /// Uploads a proof/receipt image to Storage and returns its download URL.
  Future<String> uploadReceipt({
    required String houseId,
    required String filePath,
  });

  /// Records a Deposit (money in). Positive amount; one transaction row.
  ///
  /// [transactionId] is the caller's idempotency key: a repeat of the same
  /// submission reuses it and records nothing further, so a double-tapped
  /// Deposit cannot move the money twice. Omit it and a fresh id is minted.
  Future<TransactionModel> recordDeposit({
    required String houseId,
    required double amount,
    required String performedBy,
    String? notes,
    String? receiptUrl,
    String? paidByUserId,
    String? paymentMethod,
    String? periodLabel,
    String? purpose,
    String? transactionId,
  });

  /// Records a Direct Payment (money out). Negative amount; one transaction row.
  ///
  /// Refused when the Central Account cannot cover it — the balance must never
  /// go negative. [transactionId] carries the same idempotency guarantee as
  /// [recordDeposit].
  Future<TransactionModel> recordDirectPayment({
    required String houseId,
    required double amount,
    required String performedBy,
    String? notes,
    String? receiptUrl,
    String? paymentMethod,
    String? periodLabel,
    String? categoryId,
    String? transactionId,
  });

  /// Creates a bill template (amount optional — acts as a reminder).
  Future<BillModel> createBill({
    required String houseId,
    required String title,
    double? amount,
    required DateTime dueDate,
    String categoryId = 'utilities',
    bool isRecurring = false,
  });

  /// Updates bill template fields.
  Future<void> updateBill(String billId, Map<String, dynamic> updates);

  /// Deletes a bill template.
  Future<void> deleteBill(String billId);

  /// Marks a bill as paid. Amount-bearing bills roll (if recurring) and record
  /// ONE Direct Payment transaction for the paid month — never a second one.
  Future<void> markBillPaid(
    String billId,
    BillEntity bill, {
    required String performedBy,
    String? receiptUrl,
    String? paymentMethod,
    String? periodLabel,
  });
}
