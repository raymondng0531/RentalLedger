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

  final ds = ref.watch(expenseDataSourceProvider);
  return ds
      .historyChangesStream(house.houseId)
      .asyncMap((_) => _fetchReports(ds, house.houseId));
});

Future<ReportsData> _fetchReports(
    ExpenseRemoteDataSource ds, String houseId) async {
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
    now: now,
  );
}

/// Pure computation of every report metric.
///
/// Kept free of Firebase so the business rules can be unit-tested directly.
///
/// Business rules:
/// - Money in  = every positive transaction amount (Deposits + positive
///   Adjustments + any future incoming type).
/// - Money out = every negative transaction amount (absolute value):
///   expense reimbursements + direct payments + bill payments + negative
///   Adjustments. This is ALL outgoing money — not just expense claims.
/// - Total Expenses = 'paid' expense claims only (drives the category
///   breakdown and the expense-specific insights).
/// - Pending reimbursements = 'approved' expenses not yet paid.
/// - The monthly trend shows Money In / Money Out per month (transaction
///   direction), current year only.
@visibleForTesting
ReportsData computeReportsData({
  required List<ExpenseEntity> expenses,
  required List<TransactionEntity> transactions,
  required List<BillEntity> bills,
  required Map<String, String> categoryNames,
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

  for (final t in transactions) {
    // Money In/Out split strictly by the amount's sign so future transaction
    // types are picked up automatically without touching this code.
    if (t.amount > 0) {
      moneyIn += t.amount;
      if (t.createdAt.year == current.year) {
        monthlyIn[t.createdAt.month] =
            (monthlyIn[t.createdAt.month] ?? 0) + t.amount;
      }
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
      if (t.createdAt.year == current.year) {
        monthlyOut[t.createdAt.month] =
            (monthlyOut[t.createdAt.month] ?? 0) + out;
      }
    }

    if (t.type == FirestoreConstants.transactionDeposit) {
      final amount = t.amount.abs();
      totalDeposits += amount;
      depositCount++;
      if (amount > largestDeposit) largestDeposit = amount;
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

  // Monthly trend for the current year, Jan → current month.
  final monthlyTrend = <MonthlyComparison>[];
  for (int m = 1; m <= current.month; m++) {
    monthlyTrend.add(MonthlyComparison(
      month: _monthAbbr(m),
      moneyIn: monthlyIn[m] ?? 0,
      moneyOut: monthlyOut[m] ?? 0,
    ));
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

  return ReportsData(
    categoryBreakdown: categoryBreakdown,
    monthlyTrend: monthlyTrend,
    totalExpenses: totalExpenses,
    totalDeposits: totalDeposits,
    moneyIn: moneyIn,
    moneyOut: moneyOut,
    moneyOutBreakdown: moneyOutBreakdown,
    // Same formula and same transactions as the Dashboard balance. Because
    // moneyIn and moneyOut split every transaction by sign, the identity
    // `balance == moneyIn - moneyOut` holds by construction.
    balance: computeCentralBalance(transactions.map((t) => t.amount)),
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
