import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure_codes.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/failure_messages.dart';
import '../../../../core/utils/ledger_submission_key.dart';
import '../../../../features/notifications/data/datasources/notification_remote_datasource.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../members/presentation/providers/house_provider.dart';
import '../../data/datasources/deposit_request_datasource.dart';
import '../../data/datasources/expense_ledger_datasource.dart';
import '../../data/datasources/expense_remote_datasource.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/deposit_request_entity.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/logic/deposit_request_guards.dart';
import '../../domain/repositories/expense_repository.dart';

/// Stable, non-localized codes for the failures these notifiers raise.
///
/// The notifiers have no `BuildContext`, so they never build display text:
/// they attach one of these codes to the failure they throw and the calling
/// widget maps the code to a localized message. Never compare against the
/// human-readable message — it is English and only a fallback.
class ExpenseErrorCodes {
  const ExpenseErrorCodes._();

  /// An amount-bearing bill was marked paid without its receipt/proof.
  static const String proofRequired = 'bill/proof-required';
}

/// What a notifier hands back to the screen for [error].
///
/// A stable code is returned whenever the presentation layer knows how to
/// describe it: the screen — which is the only layer holding an
/// `AppLocalizations` — turns that code into the user's own language. Anything
/// else keeps its own message, which is the documented English fallback for a
/// condition that has no code yet.
///
/// A code is only ever handed up when [FailureMessages.canDescribe] accepts it,
/// so a raw slug can never reach the screen even if a caller forgets to map it.
String _describe(Object error) {
  final code = switch (error) {
    Failure(:final code) => code,
    AppException(:final code) => code,
    _ => null,
  };
  if (code != null && FailureMessages.canDescribe(code)) return code;

  return switch (error) {
    Failure(:final message) => message,
    AppException(:final message) => message,
    _ => FailureCodes.unexpected,
  };
}

// ───── Shared Data Source Provider ─────

/// Single shared [ExpenseRemoteDataSource] for the whole feature.
///
/// Every provider/notifier in this feature (expense list, details, bills,
/// history, reports) previously constructed its own instance — each one
/// opening its own Firestore snapshot listeners on the same collections.
/// Centralising the construction keeps a single source of truth for the
/// Firestore access and avoids duplicated live listeners fighting over state.
final expenseDataSourceProvider = Provider<ExpenseRemoteDataSource>((ref) {
  return ExpenseRemoteDataSource();
});

/// Narrow money-movement surface used by the financial notifiers.
///
/// Resolves to the shared [ExpenseRemoteDataSource] at runtime, but is typed as
/// the [ExpenseLedgerDataSource] contract so deposit / direct-payment / bill
/// actions can be unit-tested against a recording fake (the concrete class
/// cannot be instantiated outside Firebase).
final expenseLedgerProvider = Provider<ExpenseLedgerDataSource>((ref) {
  return ref.watch(expenseDataSourceProvider);
});

// ───── Repository Provider ─────

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final firebaseResult = ref.watch(firebaseInitResultProvider);
  if (!firebaseResult.isSuccess) {
    return _NoOpExpenseRepository();
  }

  return ExpenseRepositoryImpl(
    remoteDataSource: ref.watch(expenseDataSourceProvider),
  );
});

// ───── Category Provider ─────

final categoriesProvider = FutureProvider<List<CategoryEntity>>((ref) {
  final house = ref.watch(currentHouseProvider);
  if (house == null) return [];

  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getCategories(house.houseId);
});

// ───── Expense List Provider (real-time) ─────

final expenseListProvider =
    StreamProvider.family<List<ExpenseEntity>, String?>((ref, status) {
  final firebaseResult = ref.watch(firebaseInitResultProvider);
  if (!firebaseResult.isSuccess) return Stream.value([]);

  final house = ref.watch(currentHouseProvider);
  if (house == null) return Stream.value([]);

  final ds = ref.watch(expenseDataSourceProvider);
  // Re-fetch whenever expenses or transactions change.
  return ds
      .historyChangesStream(house.houseId)
      .asyncMap((_) => ds.getExpenses(house.houseId, status: status));
});

// ───── Single Expense Provider (real-time) ─────

final expenseDetailProvider =
    StreamProvider.family<ExpenseEntity?, String>((ref, expenseId) {
  final firebaseResult = ref.watch(firebaseInitResultProvider);
  if (!firebaseResult.isSuccess) return Stream.value(null);

  final ds = ref.watch(expenseDataSourceProvider);
  return ds.expenseStream(expenseId);
});

// ───── Create Expense Provider ─────

final createExpenseProvider =
    AutoDisposeAsyncNotifierProvider<CreateExpenseNotifier, void>(
        CreateExpenseNotifier.new);

class CreateExpenseNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Local path to a receipt image pending upload.
  String? _pendingReceiptPath;

  /// Stores a local receipt file path to upload on submit.
  void setReceiptPath(String? path) {
    _pendingReceiptPath = path;
  }

  /// Whether a receipt has been selected.
  bool get hasReceipt => _pendingReceiptPath != null;

  /// True while a create is awaiting its upload + write. Guards against
  /// duplicate submission: a second call arriving before the first resolves
  /// (e.g. a fast double-tap before the button rebuilds disabled) must not
  /// create a second expense or re-upload the receipt.
  bool _submitting = false;

  Future<String?> createExpense({
    required String title,
    String? description,
    required String categoryId,
    required double amount,
    required String paymentSource,
    String? receiptUrl,
  }) async {
    // Duplicate-submission guard: one create at a time. A second call while the
    // first is still uploading/writing returns a no-op success (the work IS in
    // progress and will complete) instead of creating a second expense.
    if (_submitting) return null;
    _submitting = true;

    state = const AsyncValue.loading();
    try {
      final house = ref.read(currentHouseProvider);
      final userId = _currentUserId;

      if (house == null) return FailureCodes.noHouse;
      if (userId == null) return FailureCodes.notSignedIn;

      final repo = ref.read(expenseRepositoryProvider);
      // Upload receipt first if we have a local file.
      String? receiptUrl;
      if (_pendingReceiptPath != null) {
        final dataSource = ref.read(expenseDataSourceProvider);
        receiptUrl = await dataSource.uploadReceipt(
          houseId: house.houseId,
          filePath: _pendingReceiptPath!,
        );
        _pendingReceiptPath = null;
      }

      await repo.createExpense(ExpenseEntity(
        expenseId: '',
        houseId: house.houseId,
        purchasedBy: userId,
        title: title.trim(),
        description: description?.trim(),
        categoryId: categoryId,
        amount: amount,
        receiptUrl: receiptUrl,
        paymentSource: paymentSource,
        createdAt: DateTime.now(),
      ));

      // Refresh the expense list. The dashboard is NOT invalidated here
      // deliberately: dashboardDataProvider is a realtime stream that already
      // re-fetches when this Firestore write lands, and invalidating it would
      // drop its retained data for a loading skeleton on the way back.
      ref.invalidate(expenseListProvider);

      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return FailureCodes.unexpected;
    } finally {
      _submitting = false;
    }
  }

  String? get _currentUserId => _readUserId(ref);
}

// ───── Approve Expense Provider ─────

final approveExpenseProvider =
    AutoDisposeAsyncNotifierProvider<ApproveExpenseNotifier, void>(
        ApproveExpenseNotifier.new);

class ApproveExpenseNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> approve(String expenseId) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.approveExpense(expenseId, _readUserId(ref) ?? '');
      ref.invalidate(expenseDetailProvider(expenseId));
      ref.invalidate(expenseListProvider);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return FailureCodes.unexpected;
    }
  }

}

// ───── Reject Expense Provider ─────

final rejectExpenseProvider =
    AutoDisposeAsyncNotifierProvider<RejectExpenseNotifier, void>(
        RejectExpenseNotifier.new);

class RejectExpenseNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> reject(String expenseId, {String? reason}) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.rejectExpense(expenseId, _readUserId(ref) ?? '',
          reason: reason);
      ref.invalidate(expenseDetailProvider(expenseId));
      ref.invalidate(expenseListProvider);
      ref.invalidate(dashboardDataProvider);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return FailureCodes.unexpected;
    }
  }

}

// ───── Mark Paid Provider ─────

final markPaidProvider =
    AutoDisposeAsyncNotifierProvider<MarkPaidNotifier, void>(
        MarkPaidNotifier.new);

class MarkPaidNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> markPaid(String expenseId) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.markPaid(expenseId, _readUserId(ref) ?? '');
      ref.invalidate(expenseDetailProvider(expenseId));
      ref.invalidate(expenseListProvider);
      ref.invalidate(dashboardDataProvider);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return FailureCodes.unexpected;
    }
  }

}

// ───── Delete Expense Provider ─────

final deleteExpenseProvider =
    AutoDisposeAsyncNotifierProvider<DeleteExpenseNotifier, void>(
        DeleteExpenseNotifier.new);

class DeleteExpenseNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Deletes the submitter's OWN expense while it is still Pending.
  ///
  /// Guarded here (owner + status), again in the repository (which re-reads the
  /// document and rejects non-pending), and at the Firestore rule — the UI only
  /// offers the action to the owner of a pending expense, but a crafted client
  /// cannot delete another member's or a reviewed expense.
  Future<String?> delete(ExpenseEntity expense) async {
    state = const AsyncValue.loading();
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return FailureCodes.notSignedIn;

      if (expense.purchasedBy != user.uid) {
        throw const PermissionFailure(
          'You can only delete your own expense.',
        );
      }
      if (!expense.isPending) {
        throw const PermissionFailure(
          'Only pending expenses can be deleted.',
        );
      }

      final repo = ref.read(expenseRepositoryProvider);
      await repo.deleteExpense(expense.expenseId);

      // The expense is gone — drop it from detail/list/dashboard queries.
      ref.invalidate(expenseDetailProvider(expense.expenseId));
      ref.invalidate(expenseListProvider);
      ref.invalidate(dashboardDataProvider);

      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return FailureCodes.unexpected;
    }
  }

}

// ───── Deposit Provider ─────

final depositProvider =
    AutoDisposeAsyncNotifierProvider<DepositNotifier, void>(
        DepositNotifier.new);

class DepositNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Local path to the proof image pending upload.
  String? _pendingProofPath;

  /// Idempotency key for the deposit currently being submitted.
  ///
  /// Held across retries and cleared only once the movement is committed, so a
  /// double tap or a retry after a timeout reuses the SAME ledger document id
  /// and the server refuses to record the deposit twice. The next deposit then
  /// gets a fresh key and is a genuinely new movement.
  final _submissionKey = LedgerSubmissionKey();

  /// Stores the locally-chosen proof image path (blob URL on web) to upload
  /// when [deposit] runs. Mirrors [CreateExpenseNotifier.setReceiptPath].
  void setProofPath(String? path) {
    _pendingProofPath = path;
  }

  /// Whether a proof image has been selected (deposits move real money into
  /// the Central Account, so a receipt/proof is required).
  bool get hasProof => _pendingProofPath != null;

  Future<String?> deposit({
    required double amount,
    String? notes,
    String? paidByUserId,
    String? paymentMethod,
    String? periodLabel,
    String? purpose,
  }) async {
    state = const AsyncValue.loading();
    try {
      final house = ref.read(currentHouseProvider);
      if (house == null) return FailureCodes.noHouse;

      // Deposits move money into the Central Account — Treasurer-only.
      if (!_isCurrentUserTreasurer(ref)) {
        throw const PermissionFailure(
          'Only the Treasurer can record a deposit.',
        );
      }

      // Proof is REQUIRED for an actual money movement. Upload BEFORE the
      // transaction is committed so the transaction stores the resolved URL;
      // a failed upload returns an error and NO transaction is created.
      final proofPath = _pendingProofPath;
      if (proofPath == null) {
        throw const ValidationFailure(
          'A receipt or proof image is required to record a deposit.',
        );
      }

      final dataSource = ref.read(expenseLedgerProvider);
      final receiptUrl = await dataSource.uploadReceipt(
        houseId: house.houseId,
        filePath: proofPath,
      );
      // Upload succeeded — only now is the ledger touched.
      _pendingProofPath = null;

      final key = _submissionKey.key(() => const Uuid().v4());
      await dataSource.recordDeposit(
        houseId: house.houseId,
        amount: amount,
        performedBy: _readUserId(ref) ?? '',
        notes: notes,
        receiptUrl: receiptUrl,
        paidByUserId: paidByUserId,
        paymentMethod: paymentMethod,
        periodLabel: periodLabel,
        purpose: purpose,
        transactionId: key,
      );
      // Committed exactly once — the next deposit is a new movement.
      _submissionKey.clear();
      ref.invalidate(dashboardDataProvider);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } on AppException catch (e) {
      // e.g. a receipt upload failure — surface the real reason so the user can
      // retry (the pending proof is only cleared after a successful upload).
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return FailureCodes.unexpected;
    }
  }

}

// ───── Direct Payment Provider ─────

final directPaymentProvider =
    AutoDisposeAsyncNotifierProvider<DirectPaymentNotifier, void>(
        DirectPaymentNotifier.new);

class DirectPaymentNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Local path to the proof image pending upload.
  String? _pendingProofPath;

  /// Idempotency key for the payment currently being submitted — see
  /// [DepositNotifier._submissionKey].
  final _submissionKey = LedgerSubmissionKey();

  /// Stores the locally-chosen proof image path (blob URL on web) to upload
  /// when [payDirectly] runs.
  void setProofPath(String? path) {
    _pendingProofPath = path;
  }

  /// Whether a proof image has been selected (direct payments move real money
  /// out of the Central Account, so a receipt/proof is required).
  bool get hasProof => _pendingProofPath != null;

  Future<String?> payDirectly({
    required double amount,
    String? notes,
    String? categoryId,
    String? paymentMethod,
    String? periodLabel,
  }) async {
    state = const AsyncValue.loading();
    try {
      final house = ref.read(currentHouseProvider);
      if (house == null) return FailureCodes.noHouse;

      // Direct payments move money out of the Central Account — Treasurer-only.
      if (!_isCurrentUserTreasurer(ref)) {
        throw const PermissionFailure(
          'Only the Treasurer can record a direct payment.',
        );
      }

      // Proof is REQUIRED for an actual money movement. Upload BEFORE the
      // transaction is committed; a failed upload returns an error and NO
      // transaction is created.
      final proofPath = _pendingProofPath;
      if (proofPath == null) {
        throw const ValidationFailure(
          'A receipt or proof image is required to record a direct payment.',
        );
      }

      final dataSource = ref.read(expenseLedgerProvider);
      final receiptUrl = await dataSource.uploadReceipt(
        houseId: house.houseId,
        filePath: proofPath,
      );
      // Upload succeeded — only now is the ledger touched.
      _pendingProofPath = null;

      final key = _submissionKey.key(() => const Uuid().v4());
      await dataSource.recordDirectPayment(
        houseId: house.houseId,
        amount: amount,
        performedBy: _readUserId(ref) ?? '',
        notes: notes,
        receiptUrl: receiptUrl,
        categoryId: categoryId,
        paymentMethod: paymentMethod,
        periodLabel: periodLabel,
        transactionId: key,
      );
      // Committed exactly once — the next payment is a new movement.
      _submissionKey.clear();
      ref.invalidate(dashboardDataProvider);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } on AppException catch (e) {
      // e.g. a receipt upload failure — surface the real reason so the user can
      // retry (the pending proof is only cleared after a successful upload).
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return FailureCodes.unexpected;
    }
  }

}

// ───── Deposit Requests (member-submitted deposits) ─────

/// Narrow deposit-request surface. Resolves to the shared
/// [ExpenseRemoteDataSource] at runtime; typed as the
/// [DepositRequestDataSource] contract so the notifiers below can be
/// unit-tested against a recording fake.
final depositRequestDataSourceProvider =
    Provider<DepositRequestDataSource>((ref) {
  return ref.watch(expenseDataSourceProvider);
});

/// The current house's Pending deposit requests, newest first (realtime).
///
/// Every member of the house may read them; what each person is SHOWN is
/// decided by [visibleDepositRequests].
final pendingDepositRequestsProvider =
    StreamProvider<List<DepositRequestEntity>>((ref) {
  final firebaseResult = ref.watch(firebaseInitResultProvider);
  if (!firebaseResult.isSuccess) return Stream.value(const []);

  final house = ref.watch(currentHouseProvider);
  if (house == null) return Stream.value(const []);

  final ds = ref.watch(depositRequestDataSourceProvider);
  return ds.pendingDepositRequestsStream(house.houseId);
});

/// One deposit request, realtime (null once it was cancelled).
final depositRequestDetailProvider =
    StreamProvider.family<DepositRequestEntity?, String>((ref, requestId) {
  final firebaseResult = ref.watch(firebaseInitResultProvider);
  if (!firebaseResult.isSuccess) return Stream.value(null);

  final ds = ref.watch(depositRequestDataSourceProvider);
  return ds.depositRequestStream(requestId);
});

/// Which pending deposit requests a person sees on their dashboard.
///
/// The Treasurer reviews them, so they see every request in the house. A
/// member sees only their OWN requests — another member's submission is not
/// theirs to act on.
List<DepositRequestEntity> visibleDepositRequests(
  List<DepositRequestEntity> requests, {
  required String? userId,
  required bool isTreasurer,
}) {
  if (isTreasurer) return requests;
  if (userId == null) return const [];
  return [
    for (final r in requests)
      if (r.submittedBy == userId) r,
  ];
}

// ───── Submit Deposit Request Provider ─────

final submitDepositRequestProvider =
    AutoDisposeAsyncNotifierProvider<SubmitDepositRequestNotifier, void>(
        SubmitDepositRequestNotifier.new);

/// A member submits a deposit THEY paid into the Central Account.
///
/// Unlike [DepositNotifier] (the Treasurer's direct Record Deposit, which
/// writes a transaction immediately), this only creates a Pending request.
/// The money reaches the ledger when the Treasurer approves it.
class SubmitDepositRequestNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Local path to the proof image pending upload.
  String? _pendingProofPath;

  /// The proof already uploaded for the submission in flight. Kept until the
  /// request is written, so a retry after a failed write reuses it rather than
  /// uploading the same image again.
  String? _uploadedReceiptUrl;

  /// Idempotency key (= the request id) for the submission in flight. Reused
  /// across retries and cleared only once the request is written, so a double
  /// tap or a retry cannot create two requests.
  final _submissionKey = LedgerSubmissionKey();

  /// True while a submission is awaiting its upload + write.
  bool _submitting = false;

  /// Stores the locally-chosen proof image path (blob URL on web).
  void setProofPath(String? path) {
    if (path != _pendingProofPath) _uploadedReceiptUrl = null;
    _pendingProofPath = path;
  }

  /// Whether a proof image has been selected. Proof is required, mirroring
  /// expense receipts — the Treasurer approves against it.
  bool get hasProof => _pendingProofPath != null || _uploadedReceiptUrl != null;

  Future<String?> submit({
    required double amount,
    String? notes,
    String? paymentMethod,
    String? periodLabel,
    String? purpose,
  }) async {
    // One submission at a time — a second call while the first is still in
    // flight is the same submission, not a new one.
    if (_submitting) return null;
    _submitting = true;

    state = const AsyncValue.loading();
    try {
      final house = ref.read(currentHouseProvider);
      if (house == null) return FailureCodes.noHouse;
      final userId = _readUserId(ref);
      if (userId == null) return FailureCodes.notSignedIn;

      if (amount <= 0) {
        throw const ValidationFailure('Enter an amount greater than zero.');
      }
      if (!hasProof) {
        throw const ValidationFailure(
          'A receipt or proof image is required to submit a deposit.',
        );
      }

      final ds = ref.read(depositRequestDataSourceProvider);
      // Upload BEFORE the request is written; a failed upload creates nothing.
      final receiptUrl = _uploadedReceiptUrl ??= await ds.uploadReceipt(
        houseId: house.houseId,
        filePath: _pendingProofPath!,
      );

      final key = _submissionKey.key(() => const Uuid().v4());
      await ds.createDepositRequest(
        requestId: key,
        houseId: house.houseId,
        amount: amount,
        submittedBy: userId,
        paymentMethod: paymentMethod,
        periodLabel: periodLabel,
        purpose: purpose,
        notes: (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
        receiptUrl: receiptUrl,
      );

      // Written exactly once — the next submission is a new request.
      _submissionKey.clear();
      _pendingProofPath = null;
      _uploadedReceiptUrl = null;
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } on AppException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return FailureCodes.unexpected;
    } finally {
      _submitting = false;
    }
  }
}

// ───── Review Deposit Request Provider ─────

final reviewDepositRequestProvider =
    AutoDisposeAsyncNotifierProvider<ReviewDepositRequestNotifier, void>(
        ReviewDepositRequestNotifier.new);

/// The Treasurer approves or rejects a member's deposit request.
///
/// Approval is the money movement: the data source flips the request and
/// writes the Deposit transaction + balance increment in ONE Firestore
/// transaction, keyed by the request id, so a double-tapped Approve cannot
/// record the deposit twice.
class ReviewDepositRequestNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  bool _busy = false;

  Future<String?> approve(DepositRequestEntity request) =>
      _review(request, approve: true);

  Future<String?> reject(DepositRequestEntity request, {String? reason}) =>
      _review(request, approve: false, reason: reason);

  Future<String?> _review(
    DepositRequestEntity request, {
    required bool approve,
    String? reason,
  }) async {
    if (_busy) return null;
    _busy = true;

    state = const AsyncValue.loading();
    try {
      // Reviewing a deposit moves money into the Central Account —
      // Treasurer-only, exactly like the direct Record Deposit.
      if (!_isCurrentUserTreasurer(ref)) {
        throw const PermissionFailure(
          'Only the Treasurer can review a deposit.',
        );
      }
      if (!request.isPending) {
        return FailureCodes.depositRequestAlreadyReviewed;
      }

      final ds = ref.read(depositRequestDataSourceProvider);
      final treasurerId = _readUserId(ref) ?? '';
      if (approve) {
        await ds.approveDepositRequest(
          request.requestId,
          treasurerId: treasurerId,
        );
        ref.invalidate(dashboardDataProvider);
      } else {
        final trimmed = reason?.trim();
        await ds.rejectDepositRequest(
          request.requestId,
          treasurerId: treasurerId,
          reason: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
        );
      }
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } on AppException catch (e) {
      // ConflictException — already reviewed / cancelled by someone else.
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return FailureCodes.unexpected;
    } finally {
      _busy = false;
    }
  }
}

// ───── Cancel Deposit Request Provider ─────

final cancelDepositRequestProvider =
    AutoDisposeAsyncNotifierProvider<CancelDepositRequestNotifier, void>(
        CancelDepositRequestNotifier.new);

/// A member withdraws their OWN deposit request while it is still Pending.
///
/// Guarded here (owner + status), again inside the data source's transaction,
/// and at the Firestore rule.
class CancelDepositRequestNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> cancel(DepositRequestEntity request) async {
    state = const AsyncValue.loading();
    try {
      final userId = _readUserId(ref);
      if (userId == null) return FailureCodes.notSignedIn;

      final refusal = depositRequestCancelRefusal(
        userId: userId,
        submittedBy: request.submittedBy,
        currentStatus: request.status,
      );
      if (refusal != null) throw PermissionFailure(refusal);

      final ds = ref.read(depositRequestDataSourceProvider);
      await ds.cancelDepositRequest(request.requestId, userId: userId);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } on AppException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return _describe(e);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return FailureCodes.unexpected;
    }
  }
}

// ───── Bills Provider ─────

final billsProvider = StreamProvider<List<BillEntity>>((ref) {
  final firebaseResult = ref.watch(firebaseInitResultProvider);
  if (!firebaseResult.isSuccess) return Stream.value([]);

  final house = ref.watch(currentHouseProvider);
  if (house == null) return Stream.value([]);

  final ds = ref.watch(expenseDataSourceProvider);
  return ds.historyChangesStream(house.houseId).asyncMap((_) => ds.getBills(house.houseId));
});

final createBillProvider =
    AutoDisposeAsyncNotifierProvider<CreateBillNotifier, void>(
        CreateBillNotifier.new);

class CreateBillNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> createBill({
    required String title,
    double? amount,
    required DateTime dueDate,
    String categoryId = 'utilities',
    bool isRecurring = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final house = ref.read(currentHouseProvider);
      if (house == null) return FailureCodes.noHouse;

      final ds = ref.read(expenseLedgerProvider);
      await ds.createBill(
        houseId: house.houseId,
        title: title,
        amount: amount,
        dueDate: dueDate,
        categoryId: categoryId,
        isRecurring: isRecurring,
      );
      ref.invalidate(billsProvider);
      state = const AsyncValue.data(null);
      return null;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return FailureCodes.billCreateFailed;
    }
  }
}

// ───── Bill Actions Provider ─────

final billActionsProvider =
    AutoDisposeAsyncNotifierProvider<BillActionsNotifier, void>(
        BillActionsNotifier.new);

class BillActionsNotifier extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Toggles the recurring flag.
  Future<void> toggleRecurring(BillEntity bill) async {
    final ds = ref.read(expenseLedgerProvider);
    await ds.updateBill(bill.billId, {'isRecurring': !bill.isRecurring});
    ref.invalidate(billsProvider);
  }

  /// Toggles the reminder flag.
  Future<void> toggleReminder(BillEntity bill) async {
    final ds = ref.read(expenseLedgerProvider);
    await ds.updateBill(bill.billId, {'reminderEnabled': !bill.reminderEnabled});
    ref.invalidate(billsProvider);
  }

  /// Marks a bill as paid (rolls to next month if recurring).
  ///
  /// When the bill has an amount this records a Direct Payment transaction —
  /// one per paid month — so it is a Treasurer-only financial action, and the
  /// caller must supply that month's [proofPath] (receipt image). The proof is
  /// uploaded BEFORE the bill update + ledger write; a failed upload throws
  /// and no transaction is created. Bills without an amount record no
  /// transaction and need no proof. The Member-facing bill controls are the
  /// reminder toggle and Remind Treasurer — not Mark Paid.
  Future<void> markPaid(
    BillEntity bill, {
    String? proofPath,
    String? paymentMethod,
    String? periodLabel,
  }) async {
    if (!_isCurrentUserTreasurer(ref)) {
      throw const PermissionFailure(
        'Only the Treasurer can mark a bill as paid.',
      );
    }

    final ds = ref.read(expenseLedgerProvider);

    // An amount-bearing bill payment moves real money out of the Central
    // Account → its receipt/proof must be present. Upload BEFORE any write so
    // a failed upload never leaves a transaction behind.
    String? receiptUrl;
    if (bill.hasAmount) {
      if (proofPath == null) {
        throw const AppFirebaseException(
          'A receipt or proof image is required to mark this bill as paid.',
          code: ExpenseErrorCodes.proofRequired,
        );
      }
      receiptUrl = await ds.uploadReceipt(
        houseId: bill.houseId,
        filePath: proofPath,
      );
      // Upload succeeded — only now is the ledger touched.
    }

    try {
      await ds.markBillPaid(
        bill.billId,
        bill,
        performedBy: _readUserId(ref) ?? '',
        receiptUrl: receiptUrl,
        paymentMethod: paymentMethod,
        periodLabel: periodLabel,
      );
    } on ConflictException catch (e) {
      // Already paid for that period — a double tap, or a stale tab.
      throw FirebaseFailure(e.message, code: e.code);
    } on ValidationException catch (e) {
      // The Central Account cannot cover this payment.
      throw FirebaseFailure(e.message, code: FailureCodes.insufficientBalance);
    }
    ref.invalidate(billsProvider);
  }

  /// Updates bill fields.
  Future<void> updateBill(
    String billId, {
    String? title,
    double? amount,
    bool clearAmount = false,
    DateTime? dueDate,
    bool? isRecurring,
  }) async {
    final ds = ref.read(expenseLedgerProvider);
    final updates = <String, dynamic>{
      if (title != null) 'title': title,
      if (amount != null) 'amount': amount,
      if (clearAmount) 'amount': null,
      if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate),
      if (isRecurring != null) 'isRecurring': isRecurring,
    };
    await ds.updateBill(billId, updates);
    ref.invalidate(billsProvider);
  }

  /// Deletes a bill.
  Future<void> deleteBill(String billId) async {
    final ds = ref.read(expenseLedgerProvider);
    await ds.deleteBill(billId);
    ref.invalidate(billsProvider);
  }

  /// Sends a payment-reminder notification to the Treasurer.
  Future<void> remindTreasurer(BillEntity bill) async {
    final house = ref.read(currentHouseProvider);
    final user = ref.read(currentUserProvider);
    if (house == null || user == null) return;

    final notif = NotificationRemoteDataSource();
    await notif.createNotification(
      userId: house.treasurerId,
      title: 'Payment Reminder: ${bill.title}',
      // `storageLocale`, not the reader's locale: this string is written to
      // Firestore and deliberately not localized, so it must read the same for
      // every member of the house and stay stable if a member switches
      // language. See DateFormatUtils.storageLocale.
      body: 'Due ${DateFormatUtils.formatDateShort(bill.dueDate, DateFormatUtils.storageLocale)} · '
          'from ${house.houseName} · sent by ${user.displayName}',
      type: FirestoreConstants.notificationPaymentCompleted,
      relatedId: bill.billId,
    );
  }
}

// ───── No-OP Stub ─────

class _NoOpExpenseRepository implements ExpenseRepository {
  @override
  Future<ExpenseEntity> createExpense(ExpenseEntity expense) =>
      throw const FirebaseFailure('Firebase is not configured.');

  @override
  Future<ExpenseEntity> updateExpense(ExpenseEntity expense) =>
      throw const FirebaseFailure('Firebase is not configured.');

  @override
  Future<void> deleteExpense(String expenseId) =>
      throw const FirebaseFailure('Firebase is not configured.');

  @override
  Future<ExpenseEntity?> getExpense(String expenseId) => Future.value(null);

  @override
  Future<List<ExpenseEntity>> getExpenses(String houseId, {String? status}) =>
      Future.value([]);

  @override
  Future<ExpenseEntity> approveExpense(String expenseId, String treasurerId) =>
      throw const FirebaseFailure('Firebase is not configured.');

  @override
  Future<ExpenseEntity> rejectExpense(String expenseId, String treasurerId,
          {String? reason}) =>
      throw const FirebaseFailure('Firebase is not configured.');

  @override
  Future<ExpenseEntity> markPaid(String expenseId, String treasurerId) =>
      throw const FirebaseFailure('Firebase is not configured.');

  @override
  Future<List<CategoryEntity>> getCategories(String houseId) =>
      Future.value(CategoryEntity.defaults);

  @override
  Future<void> seedDefaultCategories(String houseId) async {}
}

/// Reads the current authenticated user's ID.
/// Returns null if not authenticated.
String? _readUserId(Ref ref) {
  final user = ref.read(currentUserProvider);
  return user?.uid;
}

/// Returns true when the signed-in user is the Treasurer of their current
/// house. Deposit, Direct Payment, and Mark-Bill-Paid are Treasurer-only
/// financial actions and are rejected for members.
bool _isCurrentUserTreasurer(Ref ref) {
  final house = ref.read(currentHouseProvider);
  final user = ref.read(currentUserProvider);
  return house != null && user != null && user.uid == house.treasurerId;
}
