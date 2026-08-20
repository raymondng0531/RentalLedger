import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../features/notifications/data/datasources/notification_remote_datasource.dart';
import '../../domain/entities/bill_entity.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/expense_entity.dart';
import '../models/bill_model.dart';
import '../models/expense_model.dart';
import '../models/transaction_model.dart';

/// Remote data source for expense CRUD, receipt upload, and categories.
class ExpenseRemoteDataSource {
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
      final file = File(filePath);
      final fileName = '${_uuid.v4()}.jpg';
      final ref = _storage.ref('receipts/$houseId/$fileName');

      // Upload with metadata.
      await ref.putFile(file, SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'houseId': houseId},
      ));

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

  Future<ExpenseModel> approveExpense(
      String expenseId, String treasurerId) async {
    try {
      // Fetch to get purchaser & title for notification.
      final existing = await getExpense(expenseId);
      if (existing == null) throw const AppFirebaseException('Expense not found.');

      final now = DateTime.now();
      await _firestore
          .collection(FirestoreConstants.expenses)
          .doc(expenseId)
          .update({
        'status': 'approved',
        'approvedBy': treasurerId,
        'approvedAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _notifyExpenseReviewed(
        expenseId,
        existing.purchasedBy,
        existing.title,
        'approved',
        treasurerId: treasurerId,
      );
      return (await getExpense(expenseId))!;
    } catch (e) {
      debugPrint('[ExpenseDataSource] approveExpense error: $e');
      throw const AppFirebaseException('Failed to approve expense.');
    }
  }

  Future<ExpenseModel> rejectExpense(
      String expenseId, String treasurerId,
      {String? reason}) async {
    try {
      final existing = await getExpense(expenseId);
      if (existing == null) throw const AppFirebaseException('Expense not found.');

      final now = DateTime.now();
      await _firestore
          .collection(FirestoreConstants.expenses)
          .doc(expenseId)
          .update({
        'status': 'rejected',
        'approvedBy': treasurerId,
        'approvedAt': Timestamp.fromDate(now),
        'rejectReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _notifyExpenseReviewed(
        expenseId,
        existing.purchasedBy,
        existing.title,
        'rejected',
        reason: reason,
        treasurerId: treasurerId,
      );
      return (await getExpense(expenseId))!;
    } catch (e) {
      debugPrint('[ExpenseDataSource] rejectExpense error: $e');
      throw const AppFirebaseException('Failed to reject expense.');
    }
  }

  Future<ExpenseModel> markPaid(
      String expenseId, String treasurerId) async {
    try {
      // Get the expense first to know the amount and house.
      final expense = await getExpense(expenseId);
      if (expense == null) {
        throw const AppFirebaseException('Expense not found.');
      }

      final now = DateTime.now();

      // Use a batch for atomic update + transaction.
      final batch = _firestore.batch();

      // Update expense status.
      batch.update(
        _firestore.collection(FirestoreConstants.expenses).doc(expenseId),
        {
          'status': 'paid',
          'reimbursedBy': treasurerId,
          'paidAt': Timestamp.fromDate(now),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      // Record reimbursement transaction and update balance.
      final txId = _uuid.v4();
      batch.set(
        _firestore.collection(FirestoreConstants.transactions).doc(txId),
        {
          'transactionId': txId,
          'houseId': expense.houseId,
          'expenseId': expenseId,
          'type': FirestoreConstants.transactionReimbursement,
          'amount': -expense.amount.abs(),
          'performedBy': treasurerId,
          'notes': 'Reimbursement: ${expense.title}',
          'createdAt': Timestamp.fromDate(now),
        },
      );

      // Update house balance.
      batch.update(
        _firestore.collection(FirestoreConstants.houses).doc(expense.houseId),
        {
          'balance': FieldValue.increment(-expense.amount.abs()),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      await _notifyReimbursed(expenseId, expense.purchasedBy, expense.title);
      return (await getExpense(expenseId))!;
    } catch (e) {
      debugPrint('[ExpenseDataSource] markPaid error: $e');
      throw const AppFirebaseException('Failed to mark as paid.');
    }
  }

  // ───── Transactions ─────

  /// Records a transaction and updates the house balance atomically.
  Future<TransactionModel> recordTransaction({
    required String houseId,
    String? expenseId,
    required String type,
    required double amount,
    required String performedBy,
    String? notes,
  }) async {
    try {
      final txId = _uuid.v4();
      final now = DateTime.now();

      // Write the transaction document (the source of truth for balance).
      final txRef = _firestore
          .collection(FirestoreConstants.transactions)
          .doc(txId);
      await txRef.set({
        'transactionId': txId,
        'houseId': houseId,
        'expenseId': expenseId,
        'type': type,
        'amount': amount,
        'performedBy': performedBy,
        'notes': notes,
        'createdAt': Timestamp.fromDate(now),
      });

      // Best-effort: update the cached balance on the house doc.
      // The dashboard computes balance from transactions anyway, so
      // a failure here should never fail the transaction itself.
      try {
        final houseRef = _firestore
            .collection(FirestoreConstants.houses)
            .doc(houseId);
        await houseRef.update({
          'balance': FieldValue.increment(amount),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('[ExpenseDataSource] balance cache update skipped: $e');
      }

      return TransactionModel(
        transactionId: txId,
        houseId: houseId,
        expenseId: expenseId,
        type: type,
        amount: amount,
        performedBy: performedBy,
        notes: notes,
        createdAt: now,
      );
    } catch (e) {
      debugPrint('[ExpenseDataSource] recordTransaction error: $e');
      throw const AppFirebaseException('Failed to record transaction.');
    }
  }

  /// Records a deposit (money into the Central Account).
  Future<TransactionModel> recordDeposit({
    required String houseId,
    required double amount,
    required String performedBy,
    String? notes,
  }) {
    return recordTransaction(
      houseId: houseId,
      type: FirestoreConstants.transactionDeposit,
      amount: amount, // positive = inflow
      performedBy: performedBy,
      notes: notes ?? 'Deposit',
    );
  }

  /// Records a direct payment (money out of the Central Account).
  Future<TransactionModel> recordDirectPayment({
    required String houseId,
    required double amount,
    required String performedBy,
    String? notes,
  }) {
    return recordTransaction(
      houseId: houseId,
      type: FirestoreConstants.transactionDirectPayment,
      amount: -amount.abs(), // negative = outflow
      performedBy: performedBy,
      notes: notes ?? 'Direct Payment',
    );
  }

  /// Records a reimbursement transaction (money out).
  Future<TransactionModel> recordReimbursement({
    required String houseId,
    required String expenseId,
    required double amount,
    required String performedBy,
  }) {
    return recordTransaction(
      houseId: houseId,
      expenseId: expenseId,
      type: FirestoreConstants.transactionReimbursement,
      amount: -amount.abs(), // negative = outflow
      performedBy: performedBy,
      notes: 'Reimbursement',
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
  Future<void> markBillPaid(
    String billId,
    BillEntity bill, {
    required String performedBy,
  }) async {
    try {
      if (bill.isRecurring) {
        // Roll to next month, clamping to the target month's last day so
        // e.g. Jan 31 rolls to Feb 28 (not Mar 3).
        final nextDue = _rollToNextMonth(bill.dueDate);
        await _firestore.collection('bills').doc(billId).update({
          'dueDate': Timestamp.fromDate(nextDue),
          'isPaid': false,
        });
      } else {
        await _firestore.collection('bills').doc(billId).update({
          'isPaid': true,
        });
      }

      // Record a Direct Payment transaction so it shows in History/Reports.
      if (bill.hasAmount) {
        await recordDirectPayment(
          houseId: bill.houseId,
          amount: bill.amount!,
          performedBy: performedBy,
          notes: 'Bill: ${bill.title}',
        );
      }
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
