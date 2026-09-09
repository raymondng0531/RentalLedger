import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/balance_utils.dart';
import '../../../../core/utils/member_name_utils.dart';
import '../../domain/entities/activity_item.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/monthly_summary.dart';

/// Remote data source for the dashboard.
///
/// Aggregates data from houses, expenses, and transactions collections
/// to build the dashboard view in a single query pass where possible.
class DashboardRemoteDataSource {
  DashboardRemoteDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Fetches all dashboard data for a house in a single method.
  Future<DashboardData> fetchDashboard(String houseId) async {
    try {
      // The independent queries run in parallel; the monthly summary then
      // reuses the open-claims list, so the Pending card and the Pending Items
      // section can never diverge — one source of truth.
      final results = await Future.wait([
        _fetchHouse(houseId),
        _fetchPendingItems(houseId),
        _fetchRecentActivity(houseId),
      ]);

      final pendingItems = results[1] as List<ActivityItem>;
      final monthly = await _fetchMonthlySummary(
        houseId,
        pendingItems: pendingItems,
      );

      return DashboardData(
        balance: (results[0] as _HouseSnapshot).balance,
        houseName: (results[0] as _HouseSnapshot).name,
        monthly: monthly,
        recentActivity: results[2] as List<ActivityItem>,
        pendingItems: pendingItems,
        currency: 'MYR',
      );
    } on AppFirebaseException {
      rethrow;
    } catch (e) {
      debugPrint('[DashboardDataSource] fetchDashboard error: $e');
      throw const AppFirebaseException('Failed to load dashboard.');
    }
  }

  /// Streams dashboard data in real-time.
  ///
  /// Re-fetches the dashboard whenever the house document, house members,
  /// expenses, or transactions change (e.g., a new expense or deposit).
  ///
  /// House members are watched so Recent Activity names re-resolve when a
  /// member edits their profile — no manual refresh or navigation needed.
  Stream<DashboardData> fetchDashboardStream(String houseId) {
    final controller = StreamController<DashboardData>();

    // A single expense/deposit write touches several watched collections, so
    // multiple snapshot listeners can call refetch() nearly simultaneously. The
    // fetches run concurrently and previously resolved in completion order — a
    // slower, STALE fetch could land last and overwrite a fresher one, leaving
    // the dashboard showing old data until the next change. Guarding each
    // refetch with a generation counter means only the newest fetch may emit;
    // anything superseded is dropped even if it finishes later.
    var refetchGeneration = 0;

    // Re-fetch on any relevant change.
    Future<void> refetch() async {
      final generation = ++refetchGeneration;
      try {
        final data = await fetchDashboard(houseId);
        if (!controller.isClosed && generation == refetchGeneration) {
          controller.add(data);
        }
      } catch (e) {
        debugPrint('[DashboardDataSource] stream refetch error: $e');
      }
    }

    final subscriptions = <StreamSubscription>[
      // House document changes (balance, name).
      _firestore
          .collection(FirestoreConstants.houses)
          .doc(houseId)
          .snapshots()
          .listen((_) => refetch()),
      // House member changes (display names, roles).
      _firestore
          .collection(FirestoreConstants.houseMembers)
          .where('houseId', isEqualTo: houseId)
          .snapshots()
          .listen((_) => refetch()),
      // Expense changes.
      _firestore
          .collection(FirestoreConstants.expenses)
          .where('houseId', isEqualTo: houseId)
          .snapshots()
          .listen((_) => refetch()),
      // Transaction changes.
      _firestore
          .collection(FirestoreConstants.transactions)
          .where('houseId', isEqualTo: houseId)
          .snapshots()
          .listen((_) => refetch()),
    ];

    // Initial load.
    refetch();

    controller.onCancel = () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  /// Fetches house name and balance.
  ///
  /// Balance is **computed from the transaction history** (the source of
  /// truth per business rules) rather than the stored `balance` field,
  /// which can go stale if a write is missed.
  Future<_HouseSnapshot> _fetchHouse(String houseId) async {
    final doc =
        await _firestore
            .collection(FirestoreConstants.houses)
            .doc(houseId)
            .get();

    final name =
        doc.exists && doc.data() != null
            ? (doc.data()!['houseName'] as String? ?? '')
            : '';
    final storedBalance =
        doc.exists && doc.data() != null
            ? ((doc.data()!['balance'] as num?)?.toDouble() ?? 0.0)
            : 0.0;

    // Compute the real balance from transactions.
    bool hasTx = false;
    try {
      final txSnapshot =
          await _firestore
              .collection(FirestoreConstants.transactions)
              .where('houseId', isEqualTo: houseId)
              .get();

      hasTx = txSnapshot.docs.isNotEmpty;
      if (hasTx) {
        // Shared with the Reports page — both sum the same transaction set.
        final balance = computeCentralBalance(
          txSnapshot.docs.map(
            (t) => (t.data()['amount'] as num?)?.toDouble() ?? 0,
          ),
        );
        return _HouseSnapshot(balance, name);
      }
    } catch (e) {
      debugPrint('[DashboardDataSource] balance compute error: $e');
      // Fall back to the stored balance if the query fails.
      return _HouseSnapshot(storedBalance, name);
    }

    // No transactions yet (e.g., a manually seeded balance).
    return _HouseSnapshot(storedBalance, name);
  }

  /// Calculates the monthly summary (money in/out) plus the Pending total.
  ///
  /// The Pending total/count are derived from the SAME open-claims list the
  /// Pending Items section renders ([pendingItems], submitted OR approved;
  /// paid/rejected never enter it), so the Pending card can never disagree
  /// with the list it describes — one source of truth, no separate query.
  ///
  /// Reactive by construction: the dashboard stream refetches on expense
  /// changes, so submitting RM12 adds RM12 to Pending, approving it keeps it,
  /// and paying/rejecting it drops it out — no manual refresh.
  Future<MonthlySummary> _fetchMonthlySummary(
    String houseId, {
    List<ActivityItem>? pendingItems,
  }) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    try {
      final pending = computePendingSummary(pendingItems ?? const []);
      final pendingTotal = pending.total;
      final pendingCount = pending.count;

      // Money In / Money Out this month: split transactions by the amount's
      // sign (same rule as the Reports page), so direct/bill payments count
      // toward Money Out.
      double moneyIn = 0;
      double moneyOut = 0;
      try {
        final txQuery =
            await _firestore
                .collection(FirestoreConstants.transactions)
                .where('houseId', isEqualTo: houseId)
                .where(
                  'createdAt',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
                )
                .where(
                  'createdAt',
                  isLessThanOrEqualTo: Timestamp.fromDate(monthEnd),
                )
                .get();

        for (final doc in txQuery.docs) {
          final amount = (doc.data()['amount'] as num?)?.toDouble() ?? 0;
          if (amount > 0) {
            moneyIn += amount;
          } else if (amount < 0) {
            moneyOut += -amount;
          }
        }
      } catch (e) {
        debugPrint('[DashboardDataSource] money query error: $e');
        // Keep going — pending still counts even if the money query fails.
      }

      return MonthlySummary(
        moneyIn: moneyIn,
        moneyOut: moneyOut,
        pendingReimbursements: pendingTotal,
        pendingCount: pendingCount,
      );
    } catch (e) {
      debugPrint('[DashboardDataSource] _fetchMonthlySummary error: $e');
      return const MonthlySummary();
    }
  }

  /// Fetches recent activity (transactions + expenses combined).
  ///
  /// Transactions and expenses are fetched **independently** (each capped at
  /// the activity limit) and merged newest-first. Expenses are always included
  /// — previously they were only fetched when the transaction count left room,
  /// so expense events (submit / approve / reject / paid) vanished behind a
  /// wall of transactions and the feed kept showing older activity.
  ///
  /// Each expense carries its CURRENT status and is dated by its latest
  /// milestone ([expenseActivityDate]), so a status change surfaces as the
  /// newest activity immediately and the old Pending/Submitted state is never
  /// shown again — the list is rebuilt from Firestore on every refetch.
  Future<List<ActivityItem>> _fetchRecentActivity(String houseId) async {
    try {
      // Build a userId → displayName map from the house's members so the
      // activity feed shows real names instead of raw Firebase UIDs.
      final nameMap = await _memberNameMap(houseId);

      // Fetch recent transactions.
      final txQuery =
          await _firestore
              .collection(FirestoreConstants.transactions)
              .where('houseId', isEqualTo: houseId)
              .orderBy('createdAt', descending: true)
              .limit(AppConstants.recentActivityLimit)
              .get();

      final transactionItems = <ActivityItem>[];

      for (final doc in txQuery.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? '';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;

        transactionItems.add(
          ActivityItem(
            id: doc.id,
            type: _mapTransactionType(type),
            title: data['notes'] as String? ?? type,
            subtitle: _formatSubtitle(data, nameMap),
            amount: amount,
            date: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            paymentSource:
                type == FirestoreConstants.transactionDeposit
                    ? FirestoreConstants.paymentCentral
                    : null,
          ),
        );
      }

      // Fetch recent expenses too — the newest expense events must always be
      // visible even when transactions are plentiful.
      final expenseQuery =
          await _firestore
              .collection(FirestoreConstants.expenses)
              .where('houseId', isEqualTo: houseId)
              .orderBy('createdAt', descending: true)
              .limit(AppConstants.recentActivityLimit)
              .get();

      final expenseItems = <ActivityItem>[];

      for (final doc in expenseQuery.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final approvedAt = (data['approvedAt'] as Timestamp?)?.toDate();
        final paidAt = (data['paidAt'] as Timestamp?)?.toDate();

        // Resolve the purchaser name: house member → expense displayName →
        // "Unknown Member". Never a UID or "a member".
        final memberName = nameMap[data['purchasedBy']];
        final expenseName = (data['displayName'] as String?)?.trim();
        final byName =
            (memberName != null && memberName.isNotEmpty)
                ? memberName
                : (expenseName != null && expenseName.isNotEmpty
                    ? expenseName
                    : 'Unknown Member');

        expenseItems.add(
          ActivityItem(
            id: doc.id,
            type: 'expense',
            title: data['title'] as String? ?? 'Expense',
            subtitle: 'by $byName',
            amount: (data['amount'] as num?)?.toDouble() ?? 0,
            // Date by the latest milestone so the newest action floats to the
            // top of the feed (matches the History timeline's dating).
            date: expenseActivityDate(
              status: status,
              createdAt: createdAt ?? DateTime.now(),
              approvedAt: approvedAt,
              paidAt: paidAt,
            ),
            status: status.isNotEmpty ? status : null,
            categoryId: data['categoryId'] as String?,
            paymentSource: data['paymentSource'] as String?,
          ),
        );
      }

      // Merge both feeds into one newest-first list, capped at the limit.
      return mergeRecentActivity(transactionItems, expenseItems);
    } catch (e) {
      debugPrint('[DashboardDataSource] _fetchRecentActivity error: $e');
      return [];
    }
  }

  /// Fetches ALL open expense claims (submitted + approved) — the single
  /// source of truth for both the Pending Items section and the Pending
  /// summary card.
  ///
  /// Paid and rejected claims are excluded — they are no longer waiting on the
  /// Treasurer. The section renders the top 5 while the card totals the FULL
  /// list, so they always agree. (The list is sorted by latest change in Dart;
  /// the section itself caps the rows it shows.)
  ///
  /// The query reuses the existing (houseId, status) composite index — no new
  /// index required. Sorting happens in Dart so a status change (which touches
  /// `updatedAt`, not `createdAt`) is honored without a 3-field index.
  Future<List<ActivityItem>> _fetchPendingItems(String houseId) async {
    try {
      final nameMap = await _memberNameMap(houseId);

      final query = await _firestore
          .collection(FirestoreConstants.expenses)
          .where('houseId', isEqualTo: houseId)
          .where('status', whereIn: [
            FirestoreConstants.statusPending,
            FirestoreConstants.statusApproved,
          ])
          .get();

      final items = <ActivityItem>[];
      for (final doc in query.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';

        // Resolve the purchaser name the same way the activity feed does.
        final memberName = nameMap[data['purchasedBy']];
        final expenseName = (data['displayName'] as String?)?.trim();
        final byName =
            (memberName != null && memberName.isNotEmpty)
                ? memberName
                : (expenseName != null && expenseName.isNotEmpty
                    ? expenseName
                    : 'Unknown Member');

        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

        items.add(
          ActivityItem(
            id: doc.id,
            type: 'expense',
            title: data['title'] as String? ?? 'Expense',
            subtitle: 'by $byName',
            amount: (data['amount'] as num?)?.toDouble() ?? 0,
            // Most recently changed claim first — submitting puts it on the
            // list, approving floats it to the top, paying/rejecting drops it
            // out of the section entirely.
            date: updatedAt ?? createdAt ?? DateTime.now(),
            status: status,
            categoryId: data['categoryId'] as String?,
            paymentSource: data['paymentSource'] as String?,
          ),
        );
      }

      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    } catch (e) {
      debugPrint('[DashboardDataSource] _fetchPendingItems error: $e');
      return [];
    }
  }

  /// Maps house member userIds to their display names.
  ///
  /// Includes **all** members for the house — active *and* inactive. A member
  /// who has since left (soft-deleted via `isActive: false`) still performed
  /// the historical activity shown in the feed, so their name must keep
  /// resolving. Display-only; no member-management logic is affected.
  ///
  /// Names use the same [resolveMemberDisplayName] priority as the rest of the
  /// app (member record → user profile → email-derived), so the Dashboard
  /// resolves exactly the names History and the detail pages do.
  Future<Map<String, String>> _memberNameMap(String houseId) async {
    final map = <String, String>{};
    try {
      final snapshot =
          await _firestore
              .collection(FirestoreConstants.houseMembers)
              .where('houseId', isEqualTo: houseId)
              .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final uid = data['userId'] as String?;
        if (uid == null) continue;
        final name = await resolveMemberDisplayName(
          _firestore,
          userId: uid,
          memberDisplayName: data['displayName'] as String?,
          memberEmail: data['email'] as String?,
        );
        if (name != null) map[uid] = name;
      }
    } catch (e) {
      debugPrint('[DashboardDataSource] member name map error: $e');
    }
    return map;
  }

  String _mapTransactionType(String type) {
    switch (type) {
      case 'Deposit':
        return 'deposit';
      case 'Reimbursement':
        return 'reimbursement';
      case 'Direct Payment':
        return 'payment';
      default:
        return 'adjustment';
    }
  }

  String? _formatSubtitle(
    Map<String, dynamic> data,
    Map<String, String> nameMap,
  ) {
    final performedBy = data['performedBy'] as String?;
    if (performedBy != null && performedBy.isNotEmpty) {
      final name = nameMap[performedBy];
      if (name != null) return 'by $name';
      return 'by Unknown Member';
    }
    return null;
  }
}

class _HouseSnapshot {
  const _HouseSnapshot(this.balance, this.name);
  final double balance;
  final String name;
}

/// Pure Pending summary: total + count of the OPEN-CLAIMS list — the exact
/// list the Pending Items section renders (submitted OR approved).
///
/// Business rule: the Pending card totals every claim still waiting on the
/// Treasurer. Submitting adds it, approving keeps it, paying/rejecting removes
/// it — and because the card is fed from this same list, the card and the
/// section can never disagree (one source of truth). Paid/rejected expenses
/// never enter the list, so they are excluded by construction. Pure so the
/// submit → approve → paid/reject transitions can be unit-tested without
/// Firestore.
@visibleForTesting
({double total, int count}) computePendingSummary(List<ActivityItem> items) {
  double total = 0;
  for (final item in items) {
    total += item.amount;
  }
  return (total: total, count: items.length);
}

/// The date to sort/show an expense by in the activity feed: its latest
/// milestone. Mirrors the History timeline, so a status change (e.g. a
/// rejection just now) surfaces as the newest activity instead of sitting at
/// the expense's original createdAt position.
///
/// - paid            → paidAt (falling back to approvedAt / createdAt)
/// - approved/rejected → approvedAt (rejection writes approvedAt too)
/// - pending / other   → createdAt
DateTime expenseActivityDate({
  required String status,
  required DateTime createdAt,
  DateTime? approvedAt,
  DateTime? paidAt,
}) {
  switch (status) {
    case FirestoreConstants.statusPaid:
      return paidAt ?? approvedAt ?? createdAt;
    case FirestoreConstants.statusApproved:
    case FirestoreConstants.statusRejected:
      return approvedAt ?? createdAt;
    default:
      return createdAt;
  }
}

/// Merges transaction + expense activity items into a single newest-first feed,
/// capped at [limit]. The dashboard always shows the most recent activity,
/// whatever its source. Pure so the ordering rule can be unit-tested.
List<ActivityItem> mergeRecentActivity(
  List<ActivityItem> transactionItems,
  List<ActivityItem> expenseItems, {
  int limit = AppConstants.recentActivityLimit,
}) {
  final merged = [...transactionItems, ...expenseItems]
    ..sort((a, b) => b.date.compareTo(a.date));
  return merged.length <= limit ? merged : merged.sublist(0, limit);
}
