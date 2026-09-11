/// The pure model behind Bill History: bills joined to the payments recorded
/// against them, the derived status, and the filter predicates.
///
/// Everything here is Firebase-free and clock-injectable so the rules can be
/// unit-tested — the page and its provider (Phase C) do only I/O and layout.
///
/// ## What Bill History is, and what it deliberately is not
///
/// This is a **bill-centric READ SURFACE over data that already exists**. It
/// adds no collection, no field, no write and no security rule. The rows come
/// from `billsProvider` (which already returns every active bill, paid and
/// unpaid alike); the payment details come from the `billPaid` events the
/// History feature already derives from direct-payment transactions.
///
/// Because it is bill-centric, a row exists for every bill the house can still
/// see. Payments that point at no such bill are NOT rendered as synthetic rows
/// — see [buildBillHistoryEntries].
library;

import 'package:flutter/material.dart';

import '../../../expenses/domain/entities/bill_entity.dart';
import '../providers/history_provider.dart';
import 'filter_periods.dart';

/// A bill's status, DERIVED from its own fields — no new Firestore field.
///
/// The vocabulary is deliberately bills-specific. History's expense milestones
/// (Pending / Approved / Rejected) describe an expense claim moving through
/// review; a bill is simply paid or not, and not-yet-paid is either late or
/// not yet due. Reusing the expense words here would misdescribe a bill.
enum BillHistoryStatus {
  /// `isPaid == true`. The bill is settled.
  paid('paid', 'Paid'),

  /// Not paid, and the due date has passed.
  overdue('overdue', 'Overdue'),

  /// Not paid, and the due date has not passed (including due TODAY).
  upcoming('upcoming', 'Upcoming');

  const BillHistoryStatus(this.key, this.label);

  /// Stable value used by the filter sheet and the active-filter chips.
  final String key;

  /// What the user reads.
  final String label;

  static BillHistoryStatus? fromKey(String key) {
    for (final s in values) {
      if (s.key == key) return s;
    }
    return null;
  }
}

/// One recorded payment against a bill, built from a `billPaid` event (which
/// in turn comes from a money-movement transaction).
///
/// A bill can have SEVERAL: a recurring bill keeps one `billId` as it rolls
/// forward, so each month's settlement is another payment against the same id.
@immutable
class BillHistoryPayment {
  const BillHistoryPayment({
    required this.eventId,
    required this.date,
    required this.amount,
    this.periodLabel,
    this.paymentMethod,
    this.receiptUrl,
    this.recordedByUserId,
    this.categoryId,
  });

  /// The originating event's id (`bill-paid-<transactionId>`).
  final String eventId;

  /// When the payment was recorded — the transaction's `createdAt`.
  final DateTime date;

  /// The amount that moved.
  final double amount;

  /// The month/period the payment covers, e.g. `2026-09`, when supplied.
  final String? periodLabel;

  /// How the money moved (e.g. 'Cash', 'Bank Transfer'), when supplied.
  final String? paymentMethod;

  /// Receipt/proof URL for the payment, when supplied.
  final String? receiptUrl;

  /// **The member who RECORDED the payment — not necessarily the payer.**
  ///
  /// This is the transaction's `performedBy`, which under the app's rules is
  /// the Treasurer (only the Treasurer may create a transaction). It answers
  /// "who entered this?", which is all the data can honestly support. The bill
  /// itself carries no member attribution at all.
  final String? recordedByUserId;

  /// The transaction's category, used only when the bill itself has none.
  final String? categoryId;
}

/// A bill plus its derived status and its recorded payments.
@immutable
class BillHistoryEntry {
  const BillHistoryEntry({
    required this.bill,
    required this.status,
    required this.payments,
    required this.categoryId,
  });

  final BillEntity bill;
  final BillHistoryStatus status;

  /// Newest first. Empty for a bill with no recorded payment — which includes
  /// EVERY amountless bill, since settling one writes no transaction.
  final List<BillHistoryPayment> payments;

  /// The bill's category, falling back to the latest payment's when the bill
  /// carries none. Resolved once here so the Category filter and the category
  /// chip can never disagree about which category a row is in.
  final String? categoryId;

  String get billId => bill.billId;
  String get title => bill.title;
  DateTime get dueDate => bill.dueDate;

  /// The amount due, or `null` for an amountless reminder bill. Deliberately
  /// NOT coerced to 0 — "no amount set" and "RM 0.00" are different facts.
  double? get amount => bill.amount;
  bool get hasAmount => bill.hasAmount;

  bool get isPaid => status == BillHistoryStatus.paid;
  bool get isOverdue => status == BillHistoryStatus.overdue;

  /// The most recent recorded payment, or `null` when there is none.
  BillHistoryPayment? get latestPayment =>
      payments.isEmpty ? null : payments.first;

  /// **The single date this row is filed under** — used for the Period filter,
  /// the newest-first ordering, and the month grouping, so a row can never
  /// filter by one date while appearing under another.
  ///
  /// * **Paid** → when the payment was recorded, because that is the event the
  ///   row is reporting. Falls back to the due date for a paid bill with no
  ///   recorded payment (every amountless bill, and a paid bill whose payment
  ///   transaction predates the record).
  /// * **Upcoming / Overdue** → the due date, because that is the date the
  ///   status is actually about. Using today instead would make an unfiltered
  ///   "This Month" list mean nothing.
  DateTime get filterDate {
    if (isPaid) return latestPayment?.date ?? dueDate;
    return dueDate;
  }

  /// Who recorded the latest payment, or `null` when nothing was recorded.
  String? get recordedByUserId => latestPayment?.recordedByUserId;
}

/// Decides a bill's status.
///
/// Paid wins outright: a settled bill is never reported as overdue, even when
/// the payment landed after the due date. That ordering is the whole point of
/// deriving status instead of comparing dates alone.
///
/// Otherwise the test is the same day-truncated comparison `BillEntity.daysLeft`
/// makes — `due < today`, both reduced to midnight — so this agrees with
/// `bill.isOverdue` exactly. [now] exists so tests can pin "today"; production
/// callers omit it, exactly as the entity's own getters do.
BillHistoryStatus deriveBillStatus(BillEntity bill, {DateTime? now}) {
  if (bill.isPaid) return BillHistoryStatus.paid;

  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final due = DateTime(
    bill.dueDate.year,
    bill.dueDate.month,
    bill.dueDate.day,
  );

  // due TODAY is Upcoming, not Overdue — the bill is still payable today.
  return due.isBefore(today)
      ? BillHistoryStatus.overdue
      : BillHistoryStatus.upcoming;
}

/// Joins [bills] to the payments recorded against them, newest row first.
///
/// A row is produced for every bill in [bills] — i.e. every bill the house can
/// still see — so the page is genuinely bill-centric. Bills arrive already
/// filtered to `isActive == true` by the existing query.
///
/// ## Two deliberate consequences, both pre-existing limitations
///
/// * **A payment whose `refId` matches no bill is dropped, not shown.** The
///   `billPaid` event resolves its `refId` by looking the bill up BY TITLE,
///   and falls back to the transaction id when that lookup misses (the bill was
///   deleted, renamed, or another bill shares the title). A payment that fell
///   back can never match a bill here, so a deleted bill's settlement leaves no
///   Bill History row even though it still appears in History. This is the
///   known title-linking limitation, preserved rather than papered over.
/// * **Two bills sharing a title may have their payments cross-attached**,
///   because that same lookup collapses titles. Also preserved; covered by a
///   test rather than fixed.
List<BillHistoryEntry> buildBillHistoryEntries({
  required List<BillEntity> bills,
  required List<HistoryEvent> events,
  DateTime? now,
}) {
  // Group the payments by the bill they claim to settle.
  final paymentsByBillId = <String, List<BillHistoryPayment>>{};
  for (final event in events) {
    if (event.type != HistoryEventType.billPaid) continue;
    final refId = event.refId;
    if (refId == null) continue;

    paymentsByBillId.putIfAbsent(refId, () => []).add(
      BillHistoryPayment(
        eventId: event.id,
        date: event.date,
        amount: event.amount,
        periodLabel: event.periodLabel,
        paymentMethod: event.paymentMethod,
        receiptUrl: event.receiptUrl,
        recordedByUserId: event.userId,
        categoryId: event.categoryId,
      ),
    );
  }

  final entries = <BillHistoryEntry>[];

  for (final bill in bills) {
    final payments = [...?paymentsByBillId[bill.billId]]
      ..sort((a, b) => b.date.compareTo(a.date));

    final billCategory =
        bill.categoryId.trim().isEmpty ? null : bill.categoryId;

    entries.add(
      BillHistoryEntry(
        bill: bill,
        status: deriveBillStatus(bill, now: now),
        payments: List.unmodifiable(payments),
        categoryId: billCategory ?? payments.firstOrNull?.categoryId,
      ),
    );
  }

  // Newest first, by the same date the row is filed under.
  entries.sort((a, b) => b.filterDate.compareTo(a.filterDate));
  return entries;
}

/// The Bill History filter state, as one value.
@immutable
class BillHistoryFilters {
  const BillHistoryFilters({
    this.statuses = const {},
    this.categoryId,
    this.searchQuery = '',
    this.memberUserId,
    this.preset,
    this.range,
  });

  /// Empty means "All". The sheet offers All / Paid / Upcoming / Overdue.
  final Set<BillHistoryStatus> statuses;

  /// `null` means "All Categories".
  final String? categoryId;

  /// Matched case-insensitively against the bill TITLE.
  final String searchQuery;

  /// **Filters on who RECORDED the payment — not on any owner or payer.**
  ///
  /// Only bills with a recorded payment can match, so an active member filter
  /// necessarily drops every Upcoming bill and every amountless bill. That is
  /// a property of the data (bills carry no member attribution), and the UI
  /// says so rather than implying the member owns the bill.
  final String? memberUserId;

  final String? preset;
  final DateTimeRange? range;

  bool get isEmpty =>
      statuses.isEmpty &&
      categoryId == null &&
      searchQuery.trim().isEmpty &&
      memberUserId == null &&
      preset == null &&
      range == null;

  /// How many filters are active — the badge on the filter button, matching
  /// History's counting (each populated filter counts once).
  int get activeCount =>
      (statuses.isNotEmpty ? 1 : 0) +
      (categoryId != null ? 1 : 0) +
      (memberUserId != null ? 1 : 0) +
      (preset != null || range != null ? 1 : 0) +
      (searchQuery.trim().isNotEmpty ? 1 : 0);
}

/// Applies [filters] to [entries], preserving their newest-first order.
///
/// The same predicate chain History uses — search, then the categorical
/// filters, then the date range last — so the two screens behave alike.
List<BillHistoryEntry> applyBillHistoryFilters(
  List<BillHistoryEntry> entries,
  BillHistoryFilters filters, {
  DateTime? now,
}) {
  var result = entries;

  final query = filters.searchQuery.trim().toLowerCase();
  if (query.isNotEmpty) {
    result =
        result
            .where((e) => e.title.toLowerCase().contains(query))
            .toList(growable: false);
  }

  if (filters.statuses.isNotEmpty) {
    result =
        result
            .where((e) => filters.statuses.contains(e.status))
            .toList(growable: false);
  }

  if (filters.categoryId != null) {
    result =
        result
            .where((e) => e.categoryId == filters.categoryId)
            .toList(growable: false);
  }

  if (filters.memberUserId != null) {
    result =
        result
            .where((e) => e.recordedByUserId == filters.memberUserId)
            .toList(growable: false);
  }

  // Period last, and against the row's OWN filing date — so a Paid bill is
  // selected by when it was paid while an Upcoming one is selected by when it
  // is due. Resolved through the shared vocabulary, never re-implemented.
  final range = FilterPeriods.resolve(
    preset: filters.preset,
    range: filters.range,
    now: now,
  );
  if (range != null) {
    result =
        result
            .where((e) => FilterPeriods.contains(range, e.filterDate))
            .toList(growable: false);
  }

  return result;
}
