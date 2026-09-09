import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../features/expenses/data/datasources/expense_remote_datasource.dart';
import '../../../../features/expenses/domain/entities/bill_entity.dart';
import '../../../../features/expenses/domain/entities/expense_entity.dart';
import '../../../../features/expenses/domain/entities/transaction_entity.dart';
import '../../../../features/expenses/presentation/providers/expense_provider.dart'
    show expenseDataSourceProvider;
import '../../../../features/members/presentation/providers/house_provider.dart';

/// The kind of business event a history entry represents.
///
/// Each event is one user-visible action — never a raw database document.
enum HistoryEventType {
  deposit,
  directPayment,
  adjustment,
  expenseSubmitted,
  expenseApproved,
  expensePaid,
  expenseRejected,
  billCreated,
  billPaid,
}

/// A single business event shown on the History timeline.
///
/// One user action produces exactly one event:
/// - A Deposit / Direct Payment / Adjustment → one event from its transaction.
/// - An expense → one event for its current milestone
///   (Submitted / Approved / Paid / Rejected). The internal Reimbursement
///   transaction is hidden — it would only duplicate the "Expense Paid" event.
/// - A bill → one "Created" event, plus one "Paid" event once settled.
///
/// The extra display fields (userId, paymentSource) are presentation data so
/// the tile can show "who", "how", and a category chip — no business logic.
class HistoryEvent {
  const HistoryEvent({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.refId,
    this.title,
    this.categoryId,
    this.status,
    this.userId,
    this.paymentSource,
    // ── Financial proof / attribution (money-movement transactions) ──
    this.paidByUserId,
    this.receiptUrl,
    this.paymentMethod,
    this.periodLabel,
    this.purpose,
  });

  /// Stable unique id (milestone-prefixed so one expense's events don't clash).
  final String id;

  /// The underlying record's id (expenseId / transactionId / billId) — used
  /// to open the right detail page when the tile is tapped.
  final String? refId;

  final HistoryEventType type;

  /// The entity this event is about: an expense title, a bill title, or a
  /// direct-payment note. Null for events with no description.
  final String? title;

  /// Signed amount (positive = money in, negative = money out).
  final double amount;

  final DateTime date;

  /// Category (expense events, bill events) — powers the Category filter.
  final String? categoryId;

  /// Expense milestone status (expense events only) — powers the Status filter.
  final String? status;

  /// Who performed the action (expense purchaser / transaction performer).
  final String? userId;

  /// Payment source ('personal' | 'central') — powers the method chip.
  final String? paymentSource;

  /// The member who physically paid money IN (deposit payer). The recorder is
  /// [userId] (the Treasurer). Null for money-out events and legacy deposits.
  final String? paidByUserId;

  /// Receipt/proof download URL for the money movement, when present.
  final String? receiptUrl;

  /// How the money moved (e.g. 'Cash', 'Bank Transfer').
  final String? paymentMethod;

  /// The month/period a payment or contribution covers, e.g. `2026-09`.
  final String? periodLabel;

  /// Structured purpose (e.g. 'Monthly Rental' / 'House Contribution').
  final String? purpose;
}

/// Provider that streams business events for the house in real-time.
///
/// [filterKey] is a comma-joined string of selected type filters. An empty
/// string means "all types". It is only used to key/invalidate the family —
/// filtering happens client-side on the page.
final historyProvider = StreamProvider.family<List<HistoryEvent>, String>((
  ref,
  filterKey,
) {
  final firebaseResult = ref.watch(firebaseInitResultProvider);
  if (!firebaseResult.isSuccess) {
    return Stream.error(const FirebaseFailure('Firebase is not configured.'));
  }

  final house = ref.watch(currentHouseProvider);
  if (house == null) return Stream.value(const []);

  final dataSource = ref.watch(expenseDataSourceProvider);

  // Re-fetch whenever transactions, expenses, or bills change.
  return dataSource
      .historyChangesStream(house.houseId)
      .asyncMap((_) => _fetchHistory(dataSource, house.houseId));
});

Future<List<HistoryEvent>> _fetchHistory(
  ExpenseRemoteDataSource dataSource,
  String houseId,
) async {
  try {
    final expenses = await dataSource.getExpenses(houseId);
    final transactions = await dataSource.getAllTransactions(houseId);
    final bills = await dataSource.getBills(houseId);
    return buildHistoryEvents(
      expenses: expenses,
      transactions: transactions,
      bills: bills,
    );
  } catch (e) {
    throw FirebaseFailure('Failed to load history: ${e.toString()}');
  }
}

/// Pure aggregation of raw records into one event per business action.
///
/// Kept free of Firebase so the dedup/milestone rules can be unit-tested.
@visibleForTesting
List<HistoryEvent> buildHistoryEvents({
  required List<ExpenseEntity> expenses,
  required List<TransactionEntity> transactions,
  required List<BillEntity> bills,
}) {
  final events = <HistoryEvent>[];
  // Bill title → category / billId, so a "Bill Paid" event (which originates
  // from a Direct Payment transaction) can still show its category chip and
  // open the Bill Details page.
  final billCategoryByTitle = {for (final b in bills) b.title: b.categoryId};
  final billIdByTitle = {for (final b in bills) b.title: b.billId};

  // ── Expense milestones (one event per expense = its current stage). ──
  for (final e in expenses) {
    switch (e.status) {
      case FirestoreConstants.statusPending:
        events.add(
          HistoryEvent(
            id: 'exp-submitted-${e.expenseId}',
            type: HistoryEventType.expenseSubmitted,
            title: e.title,
            amount: e.amount,
            date: e.createdAt,
            categoryId: e.categoryId,
            status: e.status,
            refId: e.expenseId,
            userId: e.purchasedBy,
            paymentSource: e.paymentSource,
          ),
        );
      case FirestoreConstants.statusApproved:
        events.add(
          HistoryEvent(
            id: 'exp-approved-${e.expenseId}',
            type: HistoryEventType.expenseApproved,
            title: e.title,
            amount: e.amount,
            date: e.approvedAt ?? e.createdAt,
            categoryId: e.categoryId,
            status: e.status,
            refId: e.expenseId,
            userId: e.purchasedBy,
            paymentSource: e.paymentSource,
          ),
        );
      case FirestoreConstants.statusPaid:
        events.add(
          HistoryEvent(
            id: 'exp-paid-${e.expenseId}',
            type: HistoryEventType.expensePaid,
            title: e.title,
            amount: -e.amount,
            date: e.paidAt ?? e.approvedAt ?? e.createdAt,
            categoryId: e.categoryId,
            status: e.status,
            refId: e.expenseId,
            userId: e.purchasedBy,
            paymentSource: e.paymentSource,
          ),
        );
      case FirestoreConstants.statusRejected:
        events.add(
          HistoryEvent(
            id: 'exp-rejected-${e.expenseId}',
            type: HistoryEventType.expenseRejected,
            title: e.title,
            amount: e.amount,
            date: e.approvedAt ?? e.createdAt,
            categoryId: e.categoryId,
            status: e.status,
            refId: e.expenseId,
            userId: e.purchasedBy,
            paymentSource: e.paymentSource,
          ),
        );
      default:
        break;
    }
  }

  // ── Transactions. Reimbursement is skipped: paying an expense already
  // produces the "Expense Paid" event above, so showing the raw
  // Reimbursement transaction would duplicate it. ──
  for (final t in transactions) {
    switch (t.type) {
      case FirestoreConstants.transactionDeposit:
        events.add(
          HistoryEvent(
            id: 'dep-${t.transactionId}',
            type: HistoryEventType.deposit,
            refId: t.transactionId,
            title: _cleanTitle(t.notes),
            amount: t.amount,
            date: t.createdAt,
            userId: t.performedBy,
            paymentSource: FirestoreConstants.paymentCentral,
            // Money-in attribution: who physically paid (may equal the
            // Treasurer recorder on legacy deposits, where this is null).
            paidByUserId: t.paidByUserId,
            receiptUrl: t.receiptUrl,
            paymentMethod: t.paymentMethod,
            periodLabel: t.periodLabel,
            purpose: t.purpose,
          ),
        );
      case FirestoreConstants.transactionDirectPayment:
        final notes = t.notes ?? '';
        final isBill = notes.startsWith('Bill: ');
        final description =
            isBill
                ? notes.substring('Bill: '.length).trim()
                : _cleanTitle(notes);
        events.add(
          HistoryEvent(
            id:
                isBill
                    ? 'bill-paid-${t.transactionId}'
                    : 'pay-${t.transactionId}',
            type:
                isBill
                    ? HistoryEventType.billPaid
                    : HistoryEventType.directPayment,
            refId:
                isBill
                    ? (billIdByTitle[description] ?? t.transactionId)
                    : t.transactionId,
            title: description,
            amount: t.amount,
            date: t.createdAt,
            categoryId:
                isBill
                    ? (billCategoryByTitle[description] ?? t.categoryId)
                    : t.categoryId,
            userId: t.performedBy,
            paymentSource: FirestoreConstants.paymentCentral,
            receiptUrl: t.receiptUrl,
            paymentMethod: t.paymentMethod,
            periodLabel: t.periodLabel,
          ),
        );
      case FirestoreConstants.transactionAdjustment:
        events.add(
          HistoryEvent(
            id: 'adj-${t.transactionId}',
            type: HistoryEventType.adjustment,
            refId: t.transactionId,
            title: _cleanTitle(t.notes),
            amount: t.amount,
            date: t.createdAt,
            userId: t.performedBy,
          ),
        );
      case FirestoreConstants.transactionReimbursement:
        break; // represented by the expense-paid event
      default:
        break;
    }
  }

  // ── Bill created events. ──
  for (final b in bills) {
    events.add(
      HistoryEvent(
        id: 'bill-created-${b.billId}',
        type: HistoryEventType.billCreated,
        refId: b.billId,
        title: b.title,
        amount: b.amount ?? 0,
        date: b.createdAt,
        categoryId: b.categoryId,
      ),
    );
  }

  // Newest first.
  events.sort((a, b) => b.date.compareTo(a.date));
  return events;
}

/// Trims [s] to a usable title, or null when blank.
String? _cleanTitle(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  return s.trim();
}
