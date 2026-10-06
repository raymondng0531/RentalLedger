import '../models/deposit_request_model.dart';

/// The deposit-request surface of the expense data source.
///
/// A member submits a deposit for themselves ([createDepositRequest]); the
/// Treasurer approves it ([approveDepositRequest] — which writes the Deposit
/// transaction and moves the balance in the same commit) or rejects it.
///
/// Exposed as a narrow contract, like [ExpenseLedgerDataSource], so the
/// notifiers can be unit-tested against a recording fake.
abstract interface class DepositRequestDataSource {
  /// Uploads a proof image to Storage and returns its download URL.
  Future<String> uploadReceipt({
    required String houseId,
    required String filePath,
  });

  /// Creates a Pending request under [requestId] and notifies the Treasurer.
  ///
  /// [requestId] is the caller's idempotency key: a repeat of the same
  /// submission finds the request already written and creates nothing more.
  Future<DepositRequestModel> createDepositRequest({
    required String requestId,
    required String houseId,
    required double amount,
    required String submittedBy,
    String? paymentMethod,
    String? periodLabel,
    String? purpose,
    String? notes,
    required String receiptUrl,
  });

  /// Approves a Pending request: ONE Firestore transaction re-reads it,
  /// requires Pending, flips it to Approved, and writes the Deposit
  /// transaction (id = [requestId]) plus the balance increment. Throws a
  /// `ConflictException` when the request was already reviewed or removed.
  Future<void> approveDepositRequest(
    String requestId, {
    required String treasurerId,
  });

  /// Rejects a Pending request with an optional [reason]. Throws a
  /// `ConflictException` when it was already reviewed or removed.
  Future<void> rejectDepositRequest(
    String requestId, {
    required String treasurerId,
    String? reason,
  });

  /// Deletes the caller's OWN Pending request.
  Future<void> cancelDepositRequest(
    String requestId, {
    required String userId,
  });

  /// Streams the house's Pending requests, newest first.
  Stream<List<DepositRequestModel>> pendingDepositRequestsStream(
    String houseId,
  );

  /// Streams one request (null once it no longer exists).
  Stream<DepositRequestModel?> depositRequestStream(String requestId);
}
