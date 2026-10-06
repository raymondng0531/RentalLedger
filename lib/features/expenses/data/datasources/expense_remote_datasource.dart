import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cross_file/cross_file.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure_codes.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../features/notifications/data/datasources/notification_remote_datasource.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/logic/deposit_request_guards.dart';
import '../../domain/logic/financial_guards.dart';
import '../models/bill_model.dart';
import '../models/deposit_request_model.dart';
import '../models/expense_model.dart';
import '../models/transaction_model.dart';
import 'deposit_request_datasource.dart';
import 'expense_ledger_datasource.dart';

/// Remote data source for expense CRUD, receipt upload, and categories.
///
/// Implements the [ExpenseLedgerDataSource] money-movement contract (deposits,
/// direct payments, bill payments) and the [DepositRequestDataSource]
/// member-deposit contract, so the financial notifiers can be tested against
/// those narrow interfaces rather than this concrete Firebase class.
class ExpenseRemoteDataSource
    implements ExpenseLedgerDataSource, DepositRequestDataSource {
  ExpenseRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  // ───── Receipt Upload ─────

  /// Uploads a receipt image to Firebase Storage.
  /// Returns the download URL.
  Future<String> uploadReceipt({
    required String houseId,
    required String filePath,
  }) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage.ref('receipts/$houseId/$fileName');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'houseId': houseId},
      );

      if (kIsWeb) {
        // Web has no filesystem — the picker returns a blob URL, so read the
        // bytes and upload them directly. (Firebase Storage web supports
        // bytes uploads.)
        final bytes = await XFile(filePath).readAsBytes();
        await ref.putData(bytes, metadata);
      } else {
        // Native: unchanged — put the local file directly.
        final file = File(filePath);
        await ref.putFile(file, metadata);
      }

      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('[ExpenseDataSource] uploadReceipt error: $e');
      throw const AppFirebaseException('Failed to upload receipt image.');
    }
  }

  // ───── Expenses ─────

  Future<ExpenseModel> createExpense(ExpenseEntity expense) async {
    try {
      final expenseId = _uuid.v4();
      final now = DateTime.now();

      final model = ExpenseModel(
        expenseId: expenseId,
        houseId: expense.houseId,
        purchasedBy: expense.purchasedBy,
        title: expense.title,
        description: expense.description,
        categoryId: expense.categoryId,
        amount: expense.amount,
        receiptUrl: expense.receiptUrl,
        paymentSource: expense.paymentSource,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection(FirestoreConstants.expenses)
          .doc(expenseId)
          .set(model.toMap());

      // Notify treasurer. Awaited so the notification write has completed by
      // the time the submission resolves — the Treasurer's realtime stream
      // picks it up without any manual refresh.
      await _notifyExpenseSubmitted(
        expense.houseId,
        expenseId,
        expense.title,
        expense.purchasedBy,
      );

      return model;
    } catch (e) {
      debugPrint('[ExpenseDataSource] createExpense error: $e');
      throw const AppFirebaseException('Failed to submit expense.');
    }
  }

  Future<ExpenseModel> updateExpense(ExpenseEntity expense) async {
    try {
      // Only update the mutable fields. Status/approval fields belong to the
      // Treasurer workflow — they must never be overwritten by an edit.
      // Nullable fields are cleared with FieldValue.delete() because Firestore
      // rejects null values: the edit dialog sends null when the member
      // cleared a field (e.g. removing the receipt or emptying the
      // description), and without delete() the old value would silently
      // survive the edit.
      final updates = <String, dynamic>{
        'title': expense.title,
        'description': expense.description ?? FieldValue.delete(),
        'categoryId': expense.categoryId,
        'amount': expense.amount,
        'receiptUrl': expense.receiptUrl ?? FieldValue.delete(),
        'paymentSource': expense.paymentSource,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(FirestoreConstants.expenses)
          .doc(expense.expenseId)
          .update(updates);
      return ExpenseModel.fromEntity(expense);
    } catch (e) {
      debugPrint('[ExpenseDataSource] updateExpense error: $e');
      throw const AppFirebaseException('Failed to update expense.');
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      await _firestore
          .collection(FirestoreConstants.expenses)
          .doc(expenseId)
          .delete();
    } catch (e) {
      debugPrint('[ExpenseDataSource] deleteExpense error: $e');
      throw const AppFirebaseException('Failed to delete expense.');
    }
  }

  Future<ExpenseModel?> getExpense(String expenseId) async {
    try {
      final doc = await _firestore
          .collection(FirestoreConstants.expenses)
          .doc(expenseId)
          .get();
      if (!doc.exists || doc.data() == null) return null;
      return ExpenseModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('[ExpenseDataSource] getExpense error: $e');
      return null;
    }
  }

  /// Streams a single expense document for real-time updates.
  Stream<ExpenseModel?> expenseStream(String expenseId) {
    return _firestore
        .collection(FirestoreConstants.expenses)
        .doc(expenseId)
        .snapshots()
        .map((doc) =>
            doc.exists ? ExpenseModel.fromFirestore(doc) : null);
  }

  Future<List<ExpenseModel>> getExpenses(String houseId,
      {String? status}) async {
    try {
      var query = _firestore
          .collection(FirestoreConstants.expenses)
          .where('houseId', isEqualTo: houseId)
          .orderBy('createdAt', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ExpenseModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[ExpenseDataSource] getExpenses error: $e');
      throw const AppFirebaseException('Failed to load expenses.');
    }
  }

  /// Applies a guarded status transition to an expense inside a transaction.
  ///
  /// The read and the write happen in the same transaction, so Firestore's
  /// optimistic concurrency check decides the race: if another client commits
  /// the same transition first, this transaction re-runs, re-reads the document,
  /// finds a status the transition does not accept, and aborts with a
  /// [ConflictException] instead of writing twice.
  ///
  /// Returns the expense as it was BEFORE the transition — callers need the
  /// pre-transition purchaser and title to address the notification.
  Future<ExpenseModel> _transitionExpense({
    required String expenseId,
    required String targetStatus,
    required Map<String, dynamic> fields,
  }) async {
    final ref =
        _firestore.collection(FirestoreConstants.expenses).doc(expenseId);

    return _firestore.runTransaction<ExpenseModel>((tx) async {
      final snapshot = await tx.get(ref);
      if (!snapshot.exists) {
        throw const AppFirebaseException('Expense not found.');
      }

      final currentStatus = (snapshot.data()?['status'] as String?) ?? '';
      final refusal = expenseTransitionRefusal(
        currentStatus: currentStatus,
        targetStatus: targetStatus,
      );
      if (refusal != null) {
        // The refusal text is the developer-facing explanation; [code] is what
        // the UI turns into the user's language.
        throw ConflictException(
          refusal,
          code: targetStatus == expenseStatusPaid
              ? FailureCodes.notAwaitingReimbursement
              : FailureCodes.alreadyReviewed,
        );
      }

      tx.update(ref, fields);
      return ExpenseModel.fromFirestore(snapshot);
    });
  }

  Future<ExpenseModel> approveExpense(
      String expenseId, String treasurerId) async {
    try {
      final now = DateTime.now();
      final existing = await _transitionExpense(
        expenseId: expenseId,
        targetStatus: expenseStatusApproved,
        fields: {
          'status': expenseStatusApproved,
          'approvedBy': treasurerId,
          'approvedAt': Timestamp.fromDate(now),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await _notifyExpenseReviewed(
        expenseId,
        existing.purchasedBy,
        existing.title,
        'approved',
        treasurerId: treasurerId,
      );
      return (await getExpense(expenseId))!;
    } on ConflictException {
      // Already reviewed by someone else — the caller needs that reason, not a
      // generic "failed to approve".
      rethrow;
    } catch (e) {
      debugPrint('[ExpenseDataSource] approveExpense error: $e');
      throw const AppFirebaseException('Failed to approve expense.');
    }
  }

  Future<ExpenseModel> rejectExpense(
      String expenseId, String treasurerId,
      {String? reason}) async {
    try {
      final now = DateTime.now();
      final existing = await _transitionExpense(
        expenseId: expenseId,
        targetStatus: expenseStatusRejected,
        fields: {
          'status': expenseStatusRejected,
          'approvedBy': treasurerId,
          'approvedAt': Timestamp.fromDate(now),
          'rejectReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await _notifyExpenseReviewed(
        expenseId,
        existing.purchasedBy,
        existing.title,
        'rejected',
        reason: reason,
        treasurerId: treasurerId,
      );
      return (await getExpense(expenseId))!;
    } on ConflictException {
      rethrow;
    } catch (e) {
      debugPrint('[ExpenseDataSource] rejectExpense error: $e');
      throw const AppFirebaseException('Failed to reject expense.');
    }
  }

  /// Reimburses an approved expense: flips the expense to `paid`, appends the
  /// Reimbursement transaction, and decrements the balance — all or nothing.
  ///
  /// Three preconditions are enforced INSIDE the transaction, so none of them
  /// can be won by a second concurrent client:
  ///
  /// 1. The expense must still be `approved`. A stale tab, a double tap, or two
  ///    Treasurers signed in at once cannot reimburse the same claim twice.
  /// 2. The Central Account must be able to cover the payout. An affordable
  ///    reimbursement can never be pushed negative by a second one that raced
  ///    it, because both transactions read and write the same house document
  ///    and Firestore serialises them.
  /// 3. The expense, the ledger row and the balance move in ONE commit.
  ///
  /// Why the house document's `balance` is the thing checked: the authoritative
  /// balance is the sum of transaction history
  /// (`docs/05_BUSINESS_RULES.md`, "Balance Calculation"), but the client SDK
  /// cannot run a sum-over-collection query inside a transaction — it may only
  /// read documents by path. `houses.balance` is that same sum materialised,
  /// maintained atomically by every money movement (see [recordTransaction]),
  /// and is the only per-house counter a transaction can both read and write.
  /// No second balance formula is introduced: the mirror is repaired from
  /// `computeCentralBalance` in the dashboard data source.
  Future<ExpenseModel> markPaid(
      String expenseId, String treasurerId) async {
    try {
      final now = DateTime.now();
      final expenseRef =
          _firestore.collection(FirestoreConstants.expenses).doc(expenseId);

      final expense = await _firestore.runTransaction<ExpenseModel>((tx) async {
        final snapshot = await tx.get(expenseRef);
        if (!snapshot.exists) {
          throw const AppFirebaseException('Expense not found.');
        }

        // Precondition 1 — still awaiting reimbursement.
        final currentStatus = (snapshot.data()?['status'] as String?) ?? '';
        final refusal = expenseTransitionRefusal(
          currentStatus: currentStatus,
          targetStatus: expenseStatusPaid,
        );
        if (refusal != null) {
          throw ConflictException(
            refusal,
            code: FailureCodes.notAwaitingReimbursement,
          );
        }

        final model = ExpenseModel.fromFirestore(snapshot);
        final amount = model.amount.abs();
        final houseRef =
            _firestore.collection(FirestoreConstants.houses).doc(model.houseId);

        // Precondition 2 — the Central Account can cover it. Reading AND
        // writing this document inside the transaction is what serialises
        // concurrent payouts.
        final houseSnapshot = await tx.get(houseRef);
        if (!houseSnapshot.exists) {
          throw const AppFirebaseException('House not found.');
        }
        final balance =
            (houseSnapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
        final balanceRefusal = insufficientBalanceRefusal(
          balance: balance,
          amount: amount,
        );
        if (balanceRefusal != null) {
          throw ValidationException(
            balanceRefusal,
            code: FailureCodes.insufficientBalance,
            arguments: {
              FailureCodes.argAmount: amount,
              FailureCodes.argBalance: balance,
            },
          );
        }

        final txId = _uuid.v4();
        _writeLedgerRow(
          tx,
          transactionId: txId,
          houseId: model.houseId,
          expenseId: expenseId,
          type: FirestoreConstants.transactionReimbursement,
          amount: -amount,
          performedBy: treasurerId,
          notes: 'Reimbursement: ${model.title}',
          createdAt: now,
          // Copy the expense's proof so the Reimbursement (money-out) row is
          // self-contained. ONE transaction per money movement — the same
          // receipt is referenced, never a second upload.
          receiptUrl: model.receiptUrl,
        );

        tx.update(expenseRef, {
          'status': expenseStatusPaid,
          'reimbursedBy': treasurerId,
          'paidAt': Timestamp.fromDate(now),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return model;
      });

      await _notifyReimbursed(expenseId, expense.purchasedBy, expense.title);
      return (await getExpense(expenseId))!;
    } on ConflictException {
      rethrow;
    } on ValidationException {
      // Insufficient balance — a business-rule refusal the user must see.
      rethrow;
    } catch (e) {
      debugPrint('[ExpenseDataSource] markPaid error: $e');
      throw const AppFirebaseException('Failed to mark as paid.');
    }
  }

  // ───── Transactions ─────

  /// Writes one ledger row AND its effect on the balance mirror, inside an
  /// existing transaction.
  ///
  /// Both writes are in the same commit, so the ledger row and the balance can
  /// never disagree — the previous implementation updated the balance in a
  /// separate best-effort call whose failure was swallowed, which is exactly how
  /// a cached balance drifts away from the history it mirrors.
  ///
  /// The row is written under the caller's [transactionId], so a caller that
  /// replays the same submission addresses the same document (see
  /// [recordTransaction]).
  void _writeLedgerRow(
    Transaction tx, {
    required String transactionId,
    required String houseId,
    String? expenseId,
    required String type,
    required double amount,
    required String performedBy,
    String? notes,
    String? receiptUrl,
    String? paidByUserId,
    String? paymentMethod,
    String? periodLabel,
    String? purpose,
    String? categoryId,
    required DateTime createdAt,
  }) {
    tx.set(
      _firestore.collection(FirestoreConstants.transactions).doc(transactionId),
      {
        'transactionId': transactionId,
        'houseId': houseId,
        'expenseId': expenseId,
        'type': type,
        'amount': amount,
        'performedBy': performedBy,
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
        // Proof / attribution — optional, so legacy transactions still parse.
        'receiptUrl': receiptUrl,
        'paidByUserId': paidByUserId,
        'paymentMethod': paymentMethod,
        'periodLabel': periodLabel,
        'purpose': purpose,
        'categoryId': categoryId,
      },
    );

    tx.update(
      _firestore.collection(FirestoreConstants.houses).doc(houseId),
      {
        'balance': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// Records one ledger row and moves the balance with it, atomically.
  ///
  /// [transactionId] is the caller's idempotency key (see
  /// [LedgerSubmissionKey]): when a row with that id already exists the money
  /// has already moved, so this call returns that row untouched instead of
  /// recording a second movement. That is what makes a double-tapped Deposit or
  /// Direct Payment safe even when the two requests are in flight together —
  /// both read the same document inside their transaction and only one can find
  /// it missing.
  ///
  /// [requireSufficientBalance] adds the same Central Account precondition that
  /// [markPaid] enforces, for outflows that must never overdraw the account.
  Future<TransactionModel> recordTransaction({
    required String houseId,
    String? expenseId,
    required String type,
    required double amount,
    required String performedBy,
    String? notes,
    String? receiptUrl,
    String? paidByUserId,
    String? paymentMethod,
    String? periodLabel,
    String? purpose,
    String? categoryId,
    String? transactionId,
    bool requireSufficientBalance = false,
  }) async {
    final txId = transactionId ?? _uuid.v4();
    final now = DateTime.now();

    final txRef =
        _firestore.collection(FirestoreConstants.transactions).doc(txId);
    final houseRef =
        _firestore.collection(FirestoreConstants.houses).doc(houseId);

    try {
      final replayed = await _firestore.runTransaction<TransactionModel?>(
        (tx) async {
          // Every read must precede every write in a Firestore transaction.
          final existing = await tx.get(txRef);

          final needsBalance = requireSufficientBalance && amount < 0;
          final houseSnapshot = needsBalance ? await tx.get(houseRef) : null;

          // Idempotency: a row already exists for this key, so the movement
          // happened on an earlier attempt. Nothing more is written — and in
          // particular the balance is NOT moved a second time.
          if (existing.exists) return TransactionModel.fromFirestore(existing);

          if (houseSnapshot != null) {
            final balance =
                (houseSnapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
            final refusal = insufficientBalanceRefusal(
              balance: balance,
              amount: amount,
            );
            if (refusal != null) {
              throw ValidationException(
                refusal,
                code: FailureCodes.insufficientBalance,
                arguments: {
                  FailureCodes.argAmount: amount,
                  FailureCodes.argBalance: balance,
                },
              );
            }
          }

          _writeLedgerRow(
            tx,
            transactionId: txId,
            houseId: houseId,
            expenseId: expenseId,
            type: type,
            amount: amount,
            performedBy: performedBy,
            notes: notes,
            receiptUrl: receiptUrl,
            paidByUserId: paidByUserId,
            paymentMethod: paymentMethod,
            periodLabel: periodLabel,
            purpose: purpose,
            categoryId: categoryId,
            createdAt: now,
          );
          return null;
        },
      );
      // A replay is a success from the caller's point of view: the movement is
      // in the ledger exactly once.
      if (replayed != null) return replayed;

      return TransactionModel(
        transactionId: txId,
        houseId: houseId,
        expenseId: expenseId,
        type: type,
        amount: amount,
        performedBy: performedBy,
        notes: notes,
        createdAt: now,
        receiptUrl: receiptUrl,
        paidByUserId: paidByUserId,
        paymentMethod: paymentMethod,
        periodLabel: periodLabel,
        purpose: purpose,
        categoryId: categoryId,
      );
    } on ValidationException {
      // Insufficient balance — a business-rule refusal the user must see.
      rethrow;
    } catch (e) {
      debugPrint('[ExpenseDataSource] recordTransaction error: $e');
      throw const AppFirebaseException('Failed to record transaction.');
    }
  }

  /// Records a deposit (money into the Central Account).
  ///
  /// Never gated on the balance — money coming in cannot overdraw the account.
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
  }) {
    return recordTransaction(
      houseId: houseId,
      type: FirestoreConstants.transactionDeposit,
      amount: amount, // positive = inflow
      performedBy: performedBy,
      notes: notes ?? 'Deposit',
      receiptUrl: receiptUrl,
      paidByUserId: paidByUserId,
      paymentMethod: paymentMethod,
      periodLabel: periodLabel,
      purpose: purpose,
      transactionId: transactionId,
    );
  }

  /// Records a direct payment (money out of the Central Account).
  ///
  /// Money leaving the account must be affordable, so the same
  /// insufficient-balance precondition that guards reimbursement guards this —
  /// the documented rule is that the balance never goes negative.
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
  }) {
    return recordTransaction(
      houseId: houseId,
      type: FirestoreConstants.transactionDirectPayment,
      amount: -amount.abs(), // negative = outflow
      performedBy: performedBy,
      notes: notes ?? 'Direct Payment',
      receiptUrl: receiptUrl,
      paymentMethod: paymentMethod,
      periodLabel: periodLabel,
      categoryId: categoryId,
      transactionId: transactionId,
      requireSufficientBalance: true,
    );
  }

  /// Records a reimbursement transaction (money out).
  Future<TransactionModel> recordReimbursement({
    required String houseId,
    required String expenseId,
    required double amount,
    required String performedBy,
    String? receiptUrl,
    String? transactionId,
  }) {
    return recordTransaction(
      houseId: houseId,
      expenseId: expenseId,
      type: FirestoreConstants.transactionReimbursement,
      amount: -amount.abs(), // negative = outflow
      performedBy: performedBy,
      notes: 'Reimbursement',
      receiptUrl: receiptUrl,
      transactionId: transactionId,
      requireSufficientBalance: true,
    );
  }

  // ───── History Queries ─────

  /// Fetches transactions for a house, newest first.
  Future<List<TransactionModel>> getTransactions(String houseId,
      {String? type, int limit = 50}) async {
    try {
      var query = _firestore
          .collection(FirestoreConstants.transactions)
          .where('houseId', isEqualTo: houseId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[ExpenseDataSource] getTransactions error: $e');
      throw const AppFirebaseException('Failed to load transactions.');
    }
  }

  /// Fetches every transaction for a house (no limit).
  ///
  /// Used for balance computation, which must sum the full transaction set —
  /// the same query the Dashboard uses — so the Reports "Current Balance"
  /// always matches the Dashboard's Central Account Balance.
  Future<List<TransactionModel>> getAllTransactions(String houseId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreConstants.transactions)
          .where('houseId', isEqualTo: houseId)
          .get();
      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[ExpenseDataSource] getAllTransactions error: $e');
      throw const AppFirebaseException('Failed to load transactions.');
    }
  }

  /// Fetches aggregated report data for a date range.
  Future<Map<String, double>> getExpensesByCategory(
      String houseId, DateTime start, DateTime end) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreConstants.expenses)
          .where('houseId', isEqualTo: houseId)
          .where('status', whereIn: ['approved', 'paid'])
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final Map<String, double> byCategory = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final cat = data['categoryId'] as String? ?? 'other';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        byCategory[cat] = (byCategory[cat] ?? 0) + amount;
      }
      return byCategory;
    } catch (e) {
      debugPrint('[ExpenseDataSource] getExpensesByCategory error: $e');
      return {};
    }
  }

  /// Streams transaction + expense changes for real-time history.
  ///
  /// Emits immediately on subscribe, then again whenever transactions
  /// or expenses change. Callers re-query via their provider.
  Stream<void> historyChangesStream(String houseId) {
    final controller = StreamController<void>.broadcast();

    void notify() {
      if (!controller.isClosed) controller.add(null);
    }

    final subs = <StreamSubscription>[
      _firestore.collection(FirestoreConstants.transactions)
          .where('houseId', isEqualTo: houseId)
          .snapshots()
          .listen((_) => notify()),
      _firestore.collection(FirestoreConstants.expenses)
          .where('houseId', isEqualTo: houseId)
          .snapshots()
          .listen((_) => notify()),
      _firestore.collection('bills')
          .where('houseId', isEqualTo: houseId)
          .snapshots()
          .listen((_) => notify()),
    ];

    // Emit immediately so the first load isn't empty.
    scheduleMicrotask(notify);

    controller.onCancel = () {
      for (final sub in subs) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  // ───── Bills ─────

  /// Fetches active bills for a house, sorted by due date.
  Future<List<BillModel>> getBills(String houseId) async {
    try {
      final snapshot = await _firestore
          .collection('bills')
          .where('houseId', isEqualTo: houseId)
          .where('isActive', isEqualTo: true)
          .orderBy('dueDate')
          .get();

      return snapshot.docs
          .map((doc) => BillModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('[ExpenseDataSource] getBills error: $e');
      return [];
    }
  }

  /// Creates a new bill. Amount is optional (can act as a reminder).
  Future<BillModel> createBill({
    required String houseId,
    required String title,
    double? amount,
    required DateTime dueDate,
    String categoryId = 'utilities',
    bool isRecurring = false,
  }) async {
    try {
      final billId = _uuid.v4();
      final bill = BillModel(
        billId: billId,
        houseId: houseId,
        title: title,
        amount: amount,
        dueDate: dueDate,
        categoryId: categoryId,
        isRecurring: isRecurring,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('bills').doc(billId).set(bill.toMap());
      return bill;
    } catch (e) {
      debugPrint('[ExpenseDataSource] createBill error: $e');
      throw const AppFirebaseException('Failed to create bill.');
    }
  }

  /// Updates bill fields (recurring, reminder, paid status).
  Future<void> updateBill(String billId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('bills').doc(billId).update(updates);
    } catch (e) {
      debugPrint('[ExpenseDataSource] updateBill error: $e');
      throw const AppFirebaseException('Failed to update bill.');
    }
  }

  /// Marks a bill as paid, rolls it to next month if recurring,
  /// and records a Direct Payment transaction so it appears in history.
  ///
  /// Non-recurring bills are marked `isPaid: true` (so the dashboard's
  /// "Upcoming Bills" — which only shows unpaid bills — drops them).
  /// Recurring bills roll forward to next month with `isPaid: false`.
  ///
  /// The bill is a TEMPLATE: each actual monthly payment creates its own
  /// Direct Payment transaction carrying that month's [periodLabel] and its
  /// own [receiptUrl] proof. Rolling a recurring bill forward never creates a
  /// second transaction — exactly one transaction per paid month.
  /// The bill update, the Direct Payment row and the balance move in ONE
  /// transaction, so a bill can never be rolled forward without its payment
  /// landing in the ledger (or vice versa).
  ///
  /// The transaction also re-reads the bill and refuses a submission whose due
  /// date the template has already moved past — the guard for a double-tapped
  /// "Mark Paid", which previously could buy the same month twice.
  Future<void> markBillPaid(
    String billId,
    BillEntity bill, {
    required String performedBy,
    String? receiptUrl,
    String? paymentMethod,
    String? periodLabel,
  }) async {
    try {
      final billRef = _firestore.collection('bills').doc(billId);
      final houseRef =
          _firestore.collection(FirestoreConstants.houses).doc(bill.houseId);
      final now = DateTime.now();
      final txId = _uuid.v4();
      final recordsPayment = bill.hasAmount;

      await _firestore.runTransaction<void>((tx) async {
        // Every read must precede every write in a Firestore transaction.
        final snapshot = await tx.get(billRef);
        if (!snapshot.exists) {
          throw const ConflictException(
            'This bill no longer exists. Refresh to see the current list.',
            code: FailureCodes.recordMissing,
          );
        }

        final data = snapshot.data()!;
        final refusal = duplicateBillPaymentRefusal(
          isPaid: (data['isPaid'] as bool?) ?? false,
          storedDueDate: (data['dueDate'] as Timestamp?)?.toDate(),
          expectedDueDate: bill.dueDate,
        );
        if (refusal != null) {
          throw ConflictException(refusal, code: FailureCodes.billAlreadyPaid);
        }

        // Money leaving the account must be affordable, exactly as for a
        // reimbursement or a standalone Direct Payment.
        if (recordsPayment) {
          final houseSnapshot = await tx.get(houseRef);
          if (!houseSnapshot.exists) {
            throw const AppFirebaseException('House not found.');
          }
          final balance =
              (houseSnapshot.data()?['balance'] as num?)?.toDouble() ?? 0.0;
          final balanceRefusal = insufficientBalanceRefusal(
            balance: balance,
            amount: bill.amount!,
          );
          if (balanceRefusal != null) {
            throw ValidationException(
              balanceRefusal,
              code: FailureCodes.insufficientBalance,
              arguments: {
                FailureCodes.argAmount: bill.amount,
                FailureCodes.argBalance: balance,
              },
            );
          }
        }

        if (bill.isRecurring) {
          // Roll to next month, clamping to the target month's last day so
          // e.g. Jan 31 rolls to Feb 28 (not Mar 3).
          final nextDue = _rollToNextMonth(bill.dueDate);
          tx.update(billRef, {
            'dueDate': Timestamp.fromDate(nextDue),
            'isPaid': false,
          });
        } else {
          tx.update(billRef, {'isPaid': true});
        }

        // ONE Direct Payment per paid month. The recurring roll above only
        // moves the template's due date, it does not touch the ledger.
        if (recordsPayment) {
          _writeLedgerRow(
            tx,
            transactionId: txId,
            houseId: bill.houseId,
            type: FirestoreConstants.transactionDirectPayment,
            amount: -bill.amount!.abs(),
            performedBy: performedBy,
            notes: 'Bill: ${bill.title}',
            receiptUrl: receiptUrl,
            paymentMethod: paymentMethod,
            periodLabel: periodLabel,
            categoryId: bill.categoryId,
            createdAt: now,
          );
        }
      });
    } on ConflictException {
      rethrow;
    } on ValidationException {
      rethrow;
    } catch (e) {
      debugPrint('[ExpenseDataSource] markBillPaid error: $e');
      throw const AppFirebaseException('Failed to update bill.');
    }
  }

  /// Adds one month to [date], clamping the day to the target month's last
  /// day (Jan 31 → Feb 28/29, Mar 31 → Apr 30, ...).
  DateTime _rollToNextMonth(DateTime date) {
    final targetMonth = date.month == 12 ? 1 : date.month + 1;
    final targetYear = date.month == 12 ? date.year + 1 : date.year;
    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    return DateTime(targetYear, targetMonth, date.day > lastDay ? lastDay : date.day);
  }

  /// Toggles a bill's active state.
  Future<void> toggleBill(String billId, bool isActive) async {
    try {
      await _firestore.collection('bills').doc(billId).update({
        'isActive': isActive,
      });
    } catch (e) {
      debugPrint('[ExpenseDataSource] toggleBill error: $e');
    }
  }

  /// Deletes a bill.
  Future<void> deleteBill(String billId) async {
    try {
      await _firestore.collection('bills').doc(billId).delete();
    } catch (e) {
      debugPrint('[ExpenseDataSource] deleteBill error: $e');
    }
  }

  // ───── Deposit Requests ─────

  /// Creates a member's Pending deposit request and notifies the Treasurer.
  ///
  /// Nothing here touches the ledger or the balance: a request only becomes
  /// money when the Treasurer approves it ([approveDepositRequest]).
  ///
  /// The write runs in a transaction that first reads [requestId], so a repeat
  /// of the same submission (a double tap, a retry after a timeout) finds the
  /// request already written and creates nothing more — the same idempotency
  /// pattern as [recordTransaction].
  @override
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
  }) async {
    final ref =
        _firestore.collection(FirestoreConstants.depositRequests).doc(requestId);
    final model = DepositRequestModel(
      requestId: requestId,
      houseId: houseId,
      amount: amount.abs(),
      // A member submits a deposit for THEMSELVES — the payer is the submitter.
      paidByUserId: submittedBy,
      submittedBy: submittedBy,
      paymentMethod: paymentMethod,
      periodLabel: periodLabel,
      purpose: purpose,
      notes: notes,
      receiptUrl: receiptUrl,
      // status defaults to Pending — the only status a new request may have.
      createdAt: DateTime.now(),
    );

    try {
      final replayed = await _firestore.runTransaction<DepositRequestModel?>(
        (tx) async {
          final existing = await tx.get(ref);
          if (existing.exists) {
            return DepositRequestModel.fromFirestore(existing);
          }
          tx.set(ref, model.toMap());
          return null;
        },
      );
      if (replayed != null) return replayed;

      // Awaited so the Treasurer's realtime notification stream has it by the
      // time the submission resolves (same as expense submission).
      await _notifyDepositSubmitted(model);
      return model;
    } catch (e) {
      debugPrint('[ExpenseDataSource] createDepositRequest error: $e');
      throw const AppFirebaseException('Failed to submit deposit.');
    }
  }

  /// Approves a Pending deposit request — the request, the Deposit ledger row
  /// and the balance all move in ONE commit.
  ///
  /// Inside the transaction:
  /// 1. The request is re-read and must still be Pending
  ///    ([depositRequestReviewRefusal]); a second Approve racing the first
  ///    re-runs, reads Approved, and fails with a [ConflictException].
  /// 2. The Deposit row is written under the request's own id — the approval's
  ///    idempotency key — so the same request can never produce two rows. If a
  ///    row with that id somehow already exists, the request is only marked
  ///    Approved and the money is NOT moved again.
  /// 3. `performedBy` is the approving Treasurer, `paidByUserId` the member who
  ///    paid, and the member's proof is carried onto the transaction.
  @override
  Future<void> approveDepositRequest(
    String requestId, {
    required String treasurerId,
  }) async {
    final requestRef =
        _firestore.collection(FirestoreConstants.depositRequests).doc(requestId);
    final txRef =
        _firestore.collection(FirestoreConstants.transactions).doc(requestId);

    try {
      final now = DateTime.now();
      final request = await _firestore.runTransaction<DepositRequestModel>(
        (tx) async {
          // Every read must precede every write in a Firestore transaction.
          final snapshot = await tx.get(requestRef);
          if (!snapshot.exists) {
            throw const ConflictException(
              'This deposit request no longer exists.',
              code: FailureCodes.recordMissing,
            );
          }
          final model = DepositRequestModel.fromFirestore(snapshot);
          final refusal =
              depositRequestReviewRefusal(currentStatus: model.status);
          if (refusal != null) {
            throw ConflictException(
              refusal,
              code: FailureCodes.depositRequestAlreadyReviewed,
            );
          }
          final existingRow = await tx.get(txRef);

          tx.update(requestRef, {
            'status': FirestoreConstants.depositRequestApproved,
            'reviewedBy': treasurerId,
            'reviewedAt': Timestamp.fromDate(now),
            'transactionId': requestId,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (!existingRow.exists) {
            _writeLedgerRow(
              tx,
              transactionId: requestId,
              houseId: model.houseId,
              type: FirestoreConstants.transactionDeposit,
              amount: model.amount.abs(), // positive = inflow
              performedBy: treasurerId,
              notes:
                  (model.notes?.isNotEmpty ?? false) ? model.notes : 'Deposit',
              receiptUrl: model.receiptUrl,
              paidByUserId: model.paidByUserId,
              paymentMethod: model.paymentMethod,
              periodLabel: model.periodLabel,
              purpose: model.purpose,
              createdAt: now,
            );
          }
          return model;
        },
      );

      await _notifyDepositReviewed(
        request,
        approved: true,
        treasurerId: treasurerId,
      );
    } on ConflictException {
      rethrow;
    } catch (e) {
      debugPrint('[ExpenseDataSource] approveDepositRequest error: $e');
      throw const AppFirebaseException('Failed to approve deposit.');
    }
  }

  /// Rejects a Pending deposit request. Nothing is written to the ledger.
  @override
  Future<void> rejectDepositRequest(
    String requestId, {
    required String treasurerId,
    String? reason,
  }) async {
    final requestRef =
        _firestore.collection(FirestoreConstants.depositRequests).doc(requestId);

    try {
      final now = DateTime.now();
      final request = await _firestore.runTransaction<DepositRequestModel>(
        (tx) async {
          final snapshot = await tx.get(requestRef);
          if (!snapshot.exists) {
            throw const ConflictException(
              'This deposit request no longer exists.',
              code: FailureCodes.recordMissing,
            );
          }
          final model = DepositRequestModel.fromFirestore(snapshot);
          final refusal =
              depositRequestReviewRefusal(currentStatus: model.status);
          if (refusal != null) {
            throw ConflictException(
              refusal,
              code: FailureCodes.depositRequestAlreadyReviewed,
            );
          }

          tx.update(requestRef, {
            'status': FirestoreConstants.depositRequestRejected,
            'reviewedBy': treasurerId,
            'reviewedAt': Timestamp.fromDate(now),
            'rejectReason': reason,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return model;
        },
      );

      await _notifyDepositReviewed(
        request,
        approved: false,
        reason: reason,
        treasurerId: treasurerId,
      );
    } on ConflictException {
      rethrow;
    } catch (e) {
      debugPrint('[ExpenseDataSource] rejectDepositRequest error: $e');
      throw const AppFirebaseException('Failed to reject deposit.');
    }
  }

  /// Deletes the caller's OWN Pending request (re-checked inside the
  /// transaction, and again by the Firestore rule).
  @override
  Future<void> cancelDepositRequest(
    String requestId, {
    required String userId,
  }) async {
    final requestRef =
        _firestore.collection(FirestoreConstants.depositRequests).doc(requestId);

    try {
      await _firestore.runTransaction<void>((tx) async {
        final snapshot = await tx.get(requestRef);
        if (!snapshot.exists) {
          throw const ConflictException(
            'This deposit request no longer exists.',
            code: FailureCodes.recordMissing,
          );
        }
        final model = DepositRequestModel.fromFirestore(snapshot);
        final refusal = depositRequestCancelRefusal(
          userId: userId,
          submittedBy: model.submittedBy,
          currentStatus: model.status,
        );
        if (refusal != null) {
          throw ConflictException(
            refusal,
            code: model.submittedBy == userId
                ? FailureCodes.depositRequestAlreadyReviewed
                : FailureCodes.permission,
          );
        }
        tx.delete(requestRef);
      });
    } on ConflictException {
      rethrow;
    } catch (e) {
      debugPrint('[ExpenseDataSource] cancelDepositRequest error: $e');
      throw const AppFirebaseException('Failed to cancel deposit request.');
    }
  }

  /// Streams the house's Pending requests, newest first.
  ///
  /// Equality filters only (houseId + status) and the ordering is done here,
  /// so the query needs no composite index.
  @override
  Stream<List<DepositRequestModel>> pendingDepositRequestsStream(
    String houseId,
  ) {
    return _firestore
        .collection(FirestoreConstants.depositRequests)
        .where('houseId', isEqualTo: houseId)
        .where('status', isEqualTo: FirestoreConstants.depositRequestPending)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => DepositRequestModel.fromFirestore(doc))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  /// Streams one request; emits null once it no longer exists (cancelled).
  @override
  Stream<DepositRequestModel?> depositRequestStream(String requestId) {
    return _firestore
        .collection(FirestoreConstants.depositRequests)
        .doc(requestId)
        .snapshots()
        .map((doc) =>
            doc.exists ? DepositRequestModel.fromFirestore(doc) : null);
  }

  // ───── Categories ─────

  Future<List<CategoryEntity>> getCategories(String houseId) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreConstants.categories)
          .where('houseId', isEqualTo: houseId)
          .get();

      if (snapshot.docs.isEmpty) {
        return CategoryEntity.defaults;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return CategoryEntity(
          categoryId: doc.id,
          name: data['name'] as String? ?? '',
          icon: data['icon'] as String? ?? 'category',
          color: data['color'] as int? ?? 0xFF00897B,
        );
      }).toList();
    } catch (e) {
      debugPrint('[ExpenseDataSource] getCategories error: $e');
      return CategoryEntity.defaults;
    }
  }

  // ───── Notification Helpers ─────

  /// Notifies the house Treasurer that a new expense awaits approval.
  ///
  /// The recipient is the Treasurer's Firebase UID (resolved from house member
  /// data, falling back to the house document) — never a display name. The
  /// submitter is skipped, so a Treasurer who submits their own expense does
  /// not get a self-notification.
  Future<void> _notifyExpenseSubmitted(
    String houseId,
    String expenseId,
    String title,
    String purchasedBy,
  ) async {
    final treasurerId = await _findTreasurer(houseId);
    if (treasurerId == null || treasurerId.isEmpty) return;
    if (treasurerId == purchasedBy) return;

    await NotificationRemoteDataSource().createNotification(
      userId: treasurerId,
      title: 'Expense Submitted',
      body: '$title needs your approval.',
      type: FirestoreConstants.notificationExpenseSubmitted,
      relatedId: expenseId,
    );
  }

  /// Notifies the expense submitter that their claim was approved or rejected.
  ///
  /// The recipient is the submitter's Firebase UID ([purchasedBy]) — never a
  /// display name. When the Treasurer reviews their own expense the reviewer
  /// and submitter are the same person, so no notification is created.
  Future<void> _notifyExpenseReviewed(
    String expenseId,
    String purchasedBy,
    String title,
    String status, {
    String? reason,
    String? treasurerId,
  }) async {
    if (purchasedBy.isEmpty) return;
    if (purchasedBy == treasurerId) return;

    final label = status == 'approved' ? 'Approved' : 'Rejected';
    final body = status == 'rejected'
        ? '"$title" was rejected'
            '${reason != null && reason.isNotEmpty ? ' · Reason: $reason' : ''}'
        : '"$title" has been approved.';

    await NotificationRemoteDataSource().createNotification(
      userId: purchasedBy,
      title: 'Expense $label',
      body: body,
      type: status == 'approved'
          ? FirestoreConstants.notificationExpenseApproved
          : FirestoreConstants.notificationExpenseRejected,
      relatedId: expenseId,
    );
  }

  /// Notifies the ORIGINAL expense submitter that their claim was reimbursed.
  ///
  /// The recipient is the submitter's Firebase UID ([purchasedBy]) — never the
  /// Treasurer who performed the payment.
  Future<void> _notifyReimbursed(
    String expenseId,
    String purchasedBy,
    String title,
  ) async {
    if (purchasedBy.isEmpty) return;

    await NotificationRemoteDataSource().createNotification(
      userId: purchasedBy,
      title: 'Reimbursement Completed',
      body: '"$title" has been reimbursed.',
      type: FirestoreConstants.notificationPaymentCompleted,
      relatedId: expenseId,
    );
  }

  /// Notifies the Treasurer that a member submitted a deposit for approval.
  /// The submitter is skipped, so a Treasurer never notifies themselves.
  Future<void> _notifyDepositSubmitted(DepositRequestModel request) async {
    final treasurerId = await _findTreasurer(request.houseId);
    if (treasurerId == null || treasurerId.isEmpty) return;
    if (treasurerId == request.submittedBy) return;

    await NotificationRemoteDataSource().createNotification(
      userId: treasurerId,
      title: 'Deposit Submitted',
      body: 'A deposit of ${CurrencyUtils.format(request.amount)} '
          'needs your approval.',
      type: FirestoreConstants.notificationDepositSubmitted,
      relatedId: request.requestId,
    );
  }

  /// Notifies the submitting member that their deposit was approved or
  /// rejected. No notification when the reviewer is the submitter.
  Future<void> _notifyDepositReviewed(
    DepositRequestModel request, {
    required bool approved,
    String? reason,
    String? treasurerId,
  }) async {
    if (request.submittedBy.isEmpty) return;
    if (request.submittedBy == treasurerId) return;

    final amount = CurrencyUtils.format(request.amount);
    final body = approved
        ? 'Your deposit of $amount has been approved.'
        : 'Your deposit of $amount was rejected'
            '${reason != null && reason.isNotEmpty ? ' · Reason: $reason' : ''}';

    await NotificationRemoteDataSource().createNotification(
      userId: request.submittedBy,
      title: approved ? 'Deposit Approved' : 'Deposit Rejected',
      body: body,
      type: approved
          ? FirestoreConstants.notificationDepositApproved
          : FirestoreConstants.notificationDepositRejected,
      relatedId: request.requestId,
    );
  }

  /// Resolves the Treasurer's Firebase UID for a house.
  ///
  /// The authoritative source is the house member record with role
  /// 'Treasurer'; the house document's `treasurerId` is a fallback for houses
  /// created before member roles existed. Houses have few members, so the role
  /// filter is applied in Dart to avoid a composite (houseId, role) index.
  Future<String?> _findTreasurer(String houseId) async {
    try {
      final members = await _firestore
          .collection(FirestoreConstants.houseMembers)
          .where('houseId', isEqualTo: houseId)
          .get();
      for (final doc in members.docs) {
        final data = doc.data();
        if (data['role'] == FirestoreConstants.roleTreasurer) {
          final uid = data['userId'] as String?;
          if (uid != null && uid.isNotEmpty) return uid;
        }
      }
    } catch (_) {
      // Fall through to the house document.
    }

    try {
      final doc = await _firestore
          .collection(FirestoreConstants.houses)
          .doc(houseId)
          .get();
      final uid = doc.data()?['treasurerId'] as String?;
      return (uid != null && uid.isNotEmpty) ? uid : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> seedDefaultCategories(String houseId) async {
    try {
      final batch = _firestore.batch();
      for (final cat in CategoryEntity.defaults) {
        final doc = _firestore
            .collection(FirestoreConstants.categories)
            .doc('${houseId}_${cat.categoryId}');
        batch.set(doc, {
          'categoryId': cat.categoryId,
          'houseId': houseId,
          'name': cat.name,
          'icon': cat.icon,
          'color': cat.color,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[ExpenseDataSource] seedCategories error: $e');
    }
  }
}
