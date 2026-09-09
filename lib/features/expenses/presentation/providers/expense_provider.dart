import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../features/notifications/data/datasources/notification_remote_datasource.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../members/presentation/providers/house_provider.dart';
import '../../data/datasources/expense_remote_datasource.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/repositories/expense_repository.dart';

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

      if (house == null) return 'No house found.';
      if (userId == null) return 'Not authenticated.';

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
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
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
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
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
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
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
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
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
      if (user == null) return 'Not authenticated.';

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
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
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

  Future<String?> deposit({
    required double amount,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final house = ref.read(currentHouseProvider);
      if (house == null) return 'No house found.';

      // Deposits move money into the Central Account — Treasurer-only.
      if (!_isCurrentUserTreasurer(ref)) {
        throw const PermissionFailure(
          'Only the Treasurer can record a deposit.',
        );
      }

      final dataSource = ref.read(expenseDataSourceProvider);
      await dataSource.recordDeposit(
        houseId: house.houseId,
        amount: amount,
        performedBy: _readUserId(ref) ?? '',
        notes: notes,
      );
      ref.invalidate(dashboardDataProvider);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
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

  Future<String?> payDirectly({
    required double amount,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final house = ref.read(currentHouseProvider);
      if (house == null) return 'No house found.';

      // Direct payments move money out of the Central Account — Treasurer-only.
      if (!_isCurrentUserTreasurer(ref)) {
        throw const PermissionFailure(
          'Only the Treasurer can record a direct payment.',
        );
      }

      final dataSource = ref.read(expenseDataSourceProvider);
      await dataSource.recordDirectPayment(
        houseId: house.houseId,
        amount: amount,
        performedBy: _readUserId(ref) ?? '',
        notes: notes,
      );
      ref.invalidate(dashboardDataProvider);
      state = const AsyncValue.data(null);
      return null;
    } on Failure catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return e.message;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return 'An unexpected error occurred.';
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
      if (house == null) return 'No house found.';

      final ds = ref.read(expenseDataSourceProvider);
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
      return 'Failed to create bill.';
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
    final ds = ref.read(expenseDataSourceProvider);
    await ds.updateBill(bill.billId, {'isRecurring': !bill.isRecurring});
    ref.invalidate(billsProvider);
  }

  /// Toggles the reminder flag.
  Future<void> toggleReminder(BillEntity bill) async {
    final ds = ref.read(expenseDataSourceProvider);
    await ds.updateBill(bill.billId, {'reminderEnabled': !bill.reminderEnabled});
    ref.invalidate(billsProvider);
  }

  /// Marks a bill as paid (rolls to next month if recurring).
  ///
  /// When the bill has an amount this records a Direct Payment transaction,
  /// so it is a Treasurer-only financial action. The Member-facing bill
  /// controls are the reminder toggle and Remind Treasurer — not Mark Paid.
  Future<void> markPaid(BillEntity bill) async {
    if (!_isCurrentUserTreasurer(ref)) {
      throw const PermissionFailure(
        'Only the Treasurer can mark a bill as paid.',
      );
    }

    final ds = ref.read(expenseDataSourceProvider);
    await ds.markBillPaid(
      bill.billId,
      bill,
      performedBy: _readUserId(ref) ?? '',
    );
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
    final ds = ref.read(expenseDataSourceProvider);
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
    final ds = ref.read(expenseDataSourceProvider);
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
      body: 'Due ${DateFormatUtils.formatDateShort(bill.dueDate)} · '
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
