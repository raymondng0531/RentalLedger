import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/utils/balance_utils.dart';
import '../../../../features/expenses/data/datasources/expense_remote_datasource.dart';
import '../../../../features/expenses/domain/entities/bill_entity.dart';
import '../../../../features/expenses/domain/entities/expense_entity.dart';
import '../../../../features/expenses/domain/entities/transaction_entity.dart';
import '../../../../features/expenses/presentation/providers/expense_provider.dart'
    show expenseDataSourceProvider;
import '../../../../features/members/presentation/providers/house_provider.dart';

/// Category spending data for charts.
class CategorySpending {
  const CategorySpending({required this.name, required this.amount, this.color});
  final String name;
  final double amount;
  final int? color;
}

/// Monthly comparison data.
///
/// Uses money direction (positive vs negative transactions) rather than
/// transaction names, so new transaction types are picked up automatically.
class MonthlyComparison {
  const MonthlyComparison({
    required this.month,
    required this.moneyIn,
    required this.moneyOut,
  });
  final String month;
  final double moneyIn;
  final double moneyOut;

  double get net => moneyIn - moneyOut;
}

/// What makes up [ReportsData.moneyOut], split by transaction type.
///
/// `total` always equals the Money Out figure, so the two can never drift
/// apart and every negative transaction lands in exactly one bucket.
class MoneyOutBreakdown {
  const MoneyOutBreakdown({
    this.expenseReimbursements = 0,
    this.directPayments = 0,
    this.billPayments = 0,
    this.negativeAdjustments = 0,
    this.other = 0,
  });

  /// `Reimbursement` transactions (created when an expense is marked paid).
  final double expenseReimbursements;

  /// `Direct Payment` transactions whose notes are NOT prefixed with "Bill: ".
  final double directPayments;

  /// `Direct Payment` transactions whose notes start with "Bill: " (paid bills).
  final double billPayments;

  /// Negative `Adjustment` transactions.
  final double negativeAdjustments;

  /// Any other negative transaction (defensive — the app has no other types).
  final double other;

  double get total =>
      expenseReimbursements +
      directPayments +
      billPayments +
      negativeAdjustments +
      other;
}

/// Formatted reports data.
class ReportsData {
  const ReportsData({
    this.categoryBreakdown = const [],
    this.monthlyTrend = const [],
    this.totalExpenses = 0,
    this.totalDeposits = 0,
    this.moneyIn = 0,
    this.moneyOut = 0,
    this.moneyOutBreakdown = const MoneyOutBreakdown(),
    this.balance = 0,
    this.allTimeBalance = 0,
    this.highestCategoryName,
    this.highestCategoryAmount = 0,
    this.largestExpense = 0,
    this.averageMonthlyExpense = 0,
    this.avgExpenseClaim = 0,
    this.pendingReimbursements = 0,
    this.avgDeposit = 0,
    this.largestDeposit = 0,
    this.billsPaid = 0,
    this.billsPending = 0,
  });

  final List<CategorySpending> categoryBreakdown;
  final List<MonthlyComparison> monthlyTrend;
  final double totalExpenses;
  final double totalDeposits;

  /// Every positive transaction (Deposits + positive Adjustments, and any
  /// future incoming type). See [Money In / Money Out].
  final double moneyIn;

  /// Every negative transaction's absolute value (Reimbursements + Direct
  /// Payments + Bill Payments + negative Adjustments). See [Money In / Money Out].
  final double moneyOut;

  /// What makes up [moneyOut], split by transaction type. `total` == [moneyOut].
  final MoneyOutBreakdown moneyOutBreakdown;

  /// Central Account balance — always equal to the Dashboard's balance.
  /// By construction `balance == moneyIn - moneyOut`.
  final double balance;

  /// The TRUE central-account balance across ALL time, independent of any
  /// active reporting window. On the all-time report it equals [balance];
  /// when a [ReportsWindow] is applied it stays the real account balance so
  /// the filtered page can keep showing it under the windowed In/Out/Net row.
  final double allTimeBalance;

  // ── Analytics ──
  final String? highestCategoryName;
  final double highestCategoryAmount;
  final double largestExpense;
  final double averageMonthlyExpense;
  final double avgExpenseClaim;
  final double pendingReimbursements;
  final double avgDeposit;
  final double largestDeposit;
  final int billsPaid;
  final int billsPending;

  /// All-time deposits minus paid expenses. Kept as an analytical metric even
  /// though it is not shown on the page (it excludes direct payments).
  double get netFlow => totalDeposits - totalExpenses;
}

/// Period presets for the Reports date filter.
enum ReportPeriod {
  allTime('All time'),
  thisMonth('This month'),
  last3Months('Last 3 months'),
  thisYear('This year'),
  custom('Custom range');

  const ReportPeriod(this.label);

  final String label;
}

/// An immutable Reports date filter.
///
/// [customStart] and [customEnd] apply only when [period] is
/// [ReportPeriod.custom]. [customEnd] is EXCLUSIVE — the range picker converts
/// the chosen "end day" to one day past it, so "to 20 Aug" means every
/// transaction dated before 21 Aug.
@immutable
class ReportFilter {
  const ReportFilter({
    this.period = ReportPeriod.allTime,
    this.customStart,
    this.customEnd,
  });

  final ReportPeriod period;
  final DateTime? customStart;
  final DateTime? customEnd;
}

/// The resolved, half-open `[start, end)` range a report is scoped to.
///
/// [start] is the first millisecond included; [end] the first excluded.
class ReportsWindow {
  const ReportsWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

/// Holds the active Reports date filter. Changing it recomputes the report.
class ReportFilterNotifier extends Notifier<ReportFilter> {
  @override
  ReportFilter build() => const ReportFilter();

  void apply(ReportFilter filter) => state = filter;

  void reset() => state = const ReportFilter();
}

final reportFilterProvider =
    NotifierProvider<ReportFilterNotifier, ReportFilter>(
        ReportFilterNotifier.new);

/// Resolves a [ReportFilter] into a concrete [ReportsWindow], or null for
/// "all time".
///
/// The presets are month-aligned whole periods:
///  - This month    → [1st of this month, 1st of next month)
///  - Last 3 months → [1st two months ago, 1st of next month)
///  - This year     → [Jan 1, Jan 1 next year)
///  - Custom        → [customStart, customEnd) as given.
///
/// A custom filter without dates falls back to all time (no window).
ReportsWindow? resolveReportWindow(ReportFilter filter, {DateTime? now}) {
  final current = now ?? DateTime.now();
  switch (filter.period) {
    case ReportPeriod.allTime:
      return null;
    case ReportPeriod.thisMonth:
      return ReportsWindow(
        start: DateTime(current.year, current.month),
        end: DateTime(current.year, current.month + 1),
      );
    case ReportPeriod.last3Months:
      return ReportsWindow(
        start: DateTime(current.year, current.month - 2),
        end: DateTime(current.year, current.month + 1),
      );
    case ReportPeriod.thisYear:
      return ReportsWindow(
        start: DateTime(current.year),
        end: DateTime(current.year + 1),
      );
    case ReportPeriod.custom:
      final start = filter.customStart;
      final end = filter.customEnd;
      if (start == null || end == null) return null;
      return ReportsWindow(start: start, end: end);
  }
}

/// Streams reports data in real-time.
///
/// Watches the house's transactions + expenses via the change stream and
/// recomputes totals on every change — no refresh required.
final reportsProvider = StreamProvider<ReportsData>((ref) {
  final firebaseResult = ref.watch(firebaseInitResultProvider);
  if (!firebaseResult.isSuccess) {
    return Stream.error(const FirebaseFailure('Firebase is not configured.'));
  }

  final house = ref.watch(currentHouseProvider);
  if (house == null) {
    return Stream.error(const NotFoundFailure('No house found.'));
  }

  // The active date filter (all time by default). Watching it here means a
  // filter change rebuilds the stream and recomputes the report for the
  // resolved window.
  final window = resolveReportWindow(ref.watch(reportFilterProvider));

  final ds = ref.watch(expenseDataSourceProvider);
  return ds
      .historyChangesStream(house.houseId)
      .asyncMap((_) => _fetchReports(ds, house.houseId, window));
});

Future<ReportsData> _fetchReports(
    ExpenseRemoteDataSource ds, String houseId, ReportsWindow? window) async {
  final now = DateTime.now();

  // ── All expenses (for category breakdown + total). ──
  final expenses = await ds.getExpenses(houseId);

  // ── All transactions (for deposits, monthly trend, and the balance). ──
  // Fetched without a cap so the balance sums the same full set the Dashboard
  // uses.
  final transactions = await ds.getAllTransactions(houseId);

  // ── Categories (so the breakdown shows names, not raw ids). ──
  final categories = await ds.getCategories(houseId);
  final categoryNames = {for (final c in categories) c.categoryId: c.name};

  // ── Bills (informational — paid bills affect reports only through the
  //    Direct Payment transaction they create). ──
  final bills = await ds.getBills(houseId);

  return computeReportsData(
    expenses: expenses,
    transactions: transactions,
    bills: bills,
    categoryNames: categoryNames,
    window: window,
    now: now,
  );
}

/// Pure computation of every report metric.
///
/// Kept free of Firebase so the business rules can be unit-tested directly.
///
/// Business rules:
/// - Money in  = every positive transaction amount in scope (Deposits +
///   positive Adjustments + any future incoming type).
/// - Money out = every negative transaction amount in scope (absolute value):
///   expense reimbursements + direct payments + bill payments + negative
///   Adjustments. This is ALL outgoing money — not just expense claims.
/// - Total Expenses = 'paid' expense claims in scope (drives the category
///   breakdown and the expense-specific insights).
/// - Pending reimbursements = 'approved' expenses in scope not yet paid.
/// - [ReportsData.balance] reconciles to `moneyIn - moneyOut` for the scope and
///   equals the Dashboard balance on the all-time report;
///   [ReportsData.allTimeBalance] always holds the true all-time account figure.
/// - The monthly trend shows Money In / Money Out per month (transaction
///   direction). With no window it runs Jan → this month of the current year;
///   under a [ReportsWindow] it covers exactly the months the window touches.
/// - Bill counts reflect the house's overall bills regardless of the window.
///
/// When [window] is null every figure is all-time (unchanged behaviour).
@visibleForTesting
ReportsData computeReportsData({
  required List<ExpenseEntity> expenses,
  required List<TransactionEntity> transactions,
  required List<BillEntity> bills,
  required Map<String, String> categoryNames,
  ReportsWindow? window,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();

  var billsPaid = 0;
  var billsPending = 0;
  for (final b in bills) {
    if (b.isPaid) {
      billsPaid++;
    } else {
      billsPending++;
    }
  }

  double totalExpenses = 0;
  double pendingReimbursements = 0;
  double largestExpense = 0;
  int paidExpenseCount = 0;
  final byCategory = <String, double>{};
  // (year, month) pairs, so e.g. Jan 2025 and Jan 2026 are two active months.
  final activeMonths = <({int year, int month})>{};

  for (final e in expenses) {
    // Under a window only claims filed inside [start, end) are in scope.
    if (window != null && !window.contains(e.createdAt)) continue;

    // Approved but not yet reimbursed — money the household owes a member.
    // Still-pending or rejected claims are not a liability yet.
    if (e.status == FirestoreConstants.statusApproved) {
      pendingReimbursements += e.amount;
      continue;
    }
    if (e.status != FirestoreConstants.statusPaid) continue; // pending/rejected

    totalExpenses += e.amount;
    paidExpenseCount++;
    if (e.amount > largestExpense) largestExpense = e.amount;
    byCategory[e.categoryId] = (byCategory[e.categoryId] ?? 0) + e.amount;
    activeMonths.add((year: e.createdAt.year, month: e.createdAt.month));
  }

  double totalDeposits = 0;
  double largestDeposit = 0;
  int depositCount = 0;
  double moneyIn = 0;
  // Money Out is bucketed by type so it can be audited; the total is derived
  // from the buckets, so `moneyOut == moneyOutBreakdown.total` always holds.
  double reimbursementOut = 0;
  double directPaymentOut = 0;
  double billPaymentOut = 0;
  double negativeAdjustmentOut = 0;
  double otherOut = 0;
  final monthlyIn = <int, double>{};
  final monthlyOut = <int, double>{};
  // Signed amounts of the transactions in scope — what the windowed balance is
  // summed from. Unused when window == null (the balance is then all-time).
  final scopedTransactionAmounts = <double>[];

  for (final t in transactions) {
    // Under a window, only transactions dated inside [start, end) are in scope;
    // with no window every transaction counts (all-time report).
    if (window != null && !window.contains(t.createdAt)) continue;
    scopedTransactionAmounts.add(t.amount);

    // Money In/Out split strictly by the amount's sign so future transaction
    // types are picked up automatically without touching this code.
    if (t.amount > 0) {
      moneyIn += t.amount;
    } else if (t.amount < 0) {
      final out = -t.amount;
      switch (t.type) {
        case FirestoreConstants.transactionReimbursement:
          reimbursementOut += out;
        case FirestoreConstants.transactionDirectPayment:
          // Bill payments are Direct Payments whose notes start with "Bill: ".
          if ((t.notes ?? '').startsWith('Bill: ')) {
            billPaymentOut += out;
          } else {
            directPaymentOut += out;
          }
        case FirestoreConstants.transactionAdjustment:
          negativeAdjustmentOut += out;
        default:
          otherOut += out; // defensive: any other negative type
      }
    }

    if (t.type == FirestoreConstants.transactionDeposit) {
      final amount = t.amount.abs();
      totalDeposits += amount;
      depositCount++;
      if (amount > largestDeposit) largestDeposit = amount;
    }

    // Trend bucket. The all-time report only trends the current calendar year
    // (Jan → this month), as it always has; a windowed report trends every
    // month the window touches. Keyed by month-serial so a window spanning a
    // year boundary renders the correct months.
    if (window != null || t.createdAt.year == current.year) {
      final serial = _monthSerial(t.createdAt.year, t.createdAt.month);
      if (t.amount > 0) {
        monthlyIn[serial] = (monthlyIn[serial] ?? 0) + t.amount;
      } else if (t.amount < 0) {
        monthlyOut[serial] = (monthlyOut[serial] ?? 0) + (-t.amount);
      }
    }
  }

  final moneyOutBreakdown = MoneyOutBreakdown(
    expenseReimbursements: reimbursementOut,
    directPayments: directPaymentOut,
    billPayments: billPaymentOut,
    negativeAdjustments: negativeAdjustmentOut,
    other: otherOut,
  );
  final moneyOut = moneyOutBreakdown.total;

  // Monthly trend. All-time → current calendar year, Jan → this month (kept
  // unchanged). Under a window → every calendar month the window touches; a
  // multi-year span labels its months with a two-digit year ("Aug 26").
  final monthlyTrend = <MonthlyComparison>[];
  if (window == null) {
    for (int m = 1; m <= current.month; m++) {
      monthlyTrend.add(MonthlyComparison(
        month: _monthAbbr(m),
        moneyIn: monthlyIn[_monthSerial(current.year, m)] ?? 0,
        moneyOut: monthlyOut[_monthSerial(current.year, m)] ?? 0,
      ));
    }
  } else {
    // end is exclusive, so the last included day is the day before it.
    final lastIncludedDay = window.end.subtract(const Duration(days: 1));
    final spansYears = window.start.year != lastIncludedDay.year;
    final startSerial = _monthSerial(window.start.year, window.start.month);
    final endSerial = _monthSerial(lastIncludedDay.year, lastIncludedDay.month);
    for (int serial = startSerial; serial <= endSerial; serial++) {
      final year = serial ~/ 12;
      final month = (serial % 12) + 1;
      monthlyTrend.add(MonthlyComparison(
        month: spansYears ? _trendMonthLabel(year, month) : _monthAbbr(month),
        moneyIn: monthlyIn[serial] ?? 0,
        moneyOut: monthlyOut[serial] ?? 0,
      ));
    }
  }

  // Sorted category breakdown (highest first).
  final categoryBreakdown = byCategory.entries
      .map((e) => CategorySpending(
            name: categoryNames[e.key] ?? e.key,
            amount: e.value,
            color: _categoryColor(e.key),
          ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  final highestCategory =
      categoryBreakdown.isNotEmpty ? categoryBreakdown.first : null;

  // Balance = sum of signed transaction amounts (the same formula and full
  // transaction set as the Dashboard balance) → the real central-account
  // balance across all time. Under a window, [balance] instead reports the
  // period's net — equal to moneyIn - moneyOut by construction, so the summary
  // row reconciles — while allTimeBalance keeps the true account figure.
  final allTimeBalance =
      computeCentralBalance(transactions.map((t) => t.amount));
  final balance = window == null
      ? allTimeBalance
      : computeCentralBalance(scopedTransactionAmounts);

  return ReportsData(
    categoryBreakdown: categoryBreakdown,
    monthlyTrend: monthlyTrend,
    totalExpenses: totalExpenses,
    totalDeposits: totalDeposits,
    moneyIn: moneyIn,
    moneyOut: moneyOut,
    moneyOutBreakdown: moneyOutBreakdown,
    balance: balance,
    allTimeBalance: allTimeBalance,
    highestCategoryName: highestCategory?.name,
    highestCategoryAmount: highestCategory?.amount ?? 0,
    largestExpense: largestExpense,
    // Average per distinct calendar month that had spending (avoid /0).
    averageMonthlyExpense:
        activeMonths.isEmpty ? 0 : totalExpenses / activeMonths.length,
    avgExpenseClaim: paidExpenseCount == 0 ? 0 : totalExpenses / paidExpenseCount,
    pendingReimbursements: pendingReimbursements,
    avgDeposit: depositCount == 0 ? 0 : totalDeposits / depositCount,
    largestDeposit: largestDeposit,
    billsPaid: billsPaid,
    billsPending: billsPending,
  );
}

String _monthAbbr(int m) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return months[m - 1];
}

/// (year, month) → a monotonic serial (`year * 12 + month - 1`) so months can
/// be bucketed and iterated across year boundaries (Dec 2025 → Jan 2026).
int _monthSerial(int year, int month) => year * 12 + (month - 1);

/// Month label carrying a two-digit year, for trends spanning years
/// ("Aug 26" for August 2026).
String _trendMonthLabel(int year, int month) =>
    '${_monthAbbr(month)} ${(year % 100).toString().padLeft(2, '0')}';

int? _categoryColor(String cat) {
  const colors = {
    'rent': 0xFF2563EB,
    'utilities': 0xFFF97316,
    'food': 0xFF16A34A,
    'household': 0xFF7C3AED,
    'maintenance': 0xFFD97706,
    'internet': 0xFF0891B2,
  };
  return colors[cat];
}
