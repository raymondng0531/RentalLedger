import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/expenses/domain/entities/bill_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/expense_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/transaction_entity.dart';
import 'package:rental_ledger/features/reports/presentation/providers/reports_provider.dart';

ExpenseEntity _expense({
  required String id,
  required double amount,
  required String categoryId,
  required String status,
  required DateTime createdAt,
}) =>
    ExpenseEntity(
      expenseId: id,
      houseId: 'house1',
      purchasedBy: 'user1',
      title: 'Expense $id',
      categoryId: categoryId,
      amount: amount,
      paymentSource: 'personal',
      status: status,
      createdAt: createdAt,
    );

TransactionEntity _tx({
  required String id,
  required String type,
  required double amount,
  required DateTime createdAt,
  String? notes,
}) =>
    TransactionEntity(
      transactionId: id,
      houseId: 'house1',
      type: type,
      amount: amount,
      performedBy: 'user1',
      notes: notes,
      createdAt: createdAt,
    );

BillEntity _bill({required String id, required bool isPaid}) => BillEntity(
      billId: id,
      houseId: 'house1',
      title: 'Bill $id',
      dueDate: DateTime(2026, 2, 1),
      createdAt: DateTime(2026, 1, 1),
      isPaid: isPaid,
    );

void main() {
  group('computeReportsData', () {
    test('totals count paid expenses and approved-only pending reimbursements',
        () {
      final now = DateTime(2026, 3, 1);
      final data = computeReportsData(
        now: now,
        categoryNames: const {'food': 'Food', 'rent': 'Rent'},
        bills: const [],
        transactions: [
          _tx(
              id: 'd1',
              type: 'Deposit',
              amount: 1000,
              createdAt: DateTime(2026, 1, 5)),
        ],
        expenses: [
          _expense(
              id: 'e1',
              amount: 100,
              categoryId: 'food',
              status: 'paid',
              createdAt: DateTime(2026, 1, 10)),
          _expense(
              id: 'e2',
              amount: 50,
              categoryId: 'food',
              status: 'approved',
              createdAt: DateTime(2026, 1, 20)),
          _expense(
              id: 'e3',
              amount: 30,
              categoryId: 'rent',
              status: 'pending',
              createdAt: DateTime(2026, 2, 1)),
          _expense(
              id: 'e4',
              amount: 20,
              categoryId: 'rent',
              status: 'rejected',
              createdAt: DateTime(2026, 2, 2)),
          _expense(
              id: 'e5',
              amount: 200,
              categoryId: 'rent',
              status: 'paid',
              createdAt: DateTime(2026, 2, 5)),
        ],
      );

      expect(data.totalExpenses, 300);
      expect(data.pendingReimbursements, 50,
          reason: 'approved-only; pending/rejected are excluded');
      expect(data.largestExpense, 200);
      expect(data.totalDeposits, 1000);
      expect(data.netFlow, 700);

      // Highest category + breakdown.
      expect(data.highestCategoryName, 'Rent');
      expect(data.highestCategoryAmount, 200);
      expect(data.categoryBreakdown, hasLength(2));
      expect(data.categoryBreakdown.first.name, 'Rent');
      expect(data.categoryBreakdown.first.amount, 200);
      expect(data.categoryBreakdown.last.amount, 100);

      // Percentages sum to ~100%.
      final percentSum = data.categoryBreakdown
          .map((c) => c.amount / data.totalExpenses * 100)
          .fold(0.0, (a, b) => a + b);
      expect(percentSum, closeTo(100, 0.001));

      // Trend is transaction-based: the single Jan deposit shows as money in.
      expect(data.monthlyTrend, hasLength(3));
      expect(data.monthlyTrend[0].month, 'Jan');
      expect(data.monthlyTrend[0].moneyIn, 1000);
      expect(data.monthlyTrend[0].moneyOut, 0);
      expect(data.monthlyTrend[1].moneyIn, 0);
      expect(data.monthlyTrend[2].moneyIn, 0);

      // Money In − Money Out always reconciles with the balance.
      expect(data.moneyIn - data.moneyOut, data.balance);
    });

    test('pending-approval expenses are not reimbursements yet', () {
      final data = computeReportsData(
        now: DateTime(2026, 3, 1),
        categoryNames: const {},
        bills: const [],
        transactions: const [],
        expenses: [
          _expense(
              id: 'p1',
              amount: 25,
              categoryId: 'a',
              status: 'pending',
              createdAt: DateTime(2026, 1, 1)),
        ],
      );
      expect(data.pendingReimbursements, 0);
      expect(data.totalExpenses, 0);
      expect(data.categoryBreakdown, isEmpty);
    });

    test('monthly trend excludes prior-year transactions', () {
      final data = computeReportsData(
        now: DateTime(2026, 3, 1),
        categoryNames: const {},
        bills: const [],
        transactions: [
          _tx(
              id: 'd1',
              type: 'Deposit',
              amount: 900,
              createdAt: DateTime(2025, 1, 5)),
          _tx(
              id: 'd2',
              type: 'Deposit',
              amount: 100,
              createdAt: DateTime(2026, 1, 5)),
          _tx(
              id: 'r1',
              type: 'Reimbursement',
              amount: -400,
              createdAt: DateTime(2025, 1, 10)),
          _tx(
              id: 'r2',
              type: 'Reimbursement',
              amount: -100,
              createdAt: DateTime(2026, 1, 15)),
        ],
        expenses: const [],
      );

      // All-time totals include both years.
      expect(data.totalDeposits, 1000);
      expect(data.moneyIn, 1000);
      expect(data.moneyOut, 500);

      // The Jan bucket of the current-year trend shows only 2026 records.
      expect(data.monthlyTrend[0].month, 'Jan');
      expect(data.monthlyTrend[0].moneyIn, 100);
      expect(data.monthlyTrend[0].moneyOut, 100);
    });

    test('only Deposit transactions count as deposits', () {
      final data = computeReportsData(
        now: DateTime(2026, 3, 1),
        categoryNames: const {},
        bills: const [],
        transactions: [
          _tx(
              id: 'd1',
              type: 'Deposit',
              amount: 500,
              createdAt: DateTime(2026, 1, 1)),
          _tx(
              id: 'r1',
              type: 'Reimbursement',
              amount: -100,
              createdAt: DateTime(2026, 1, 2)),
          _tx(
              id: 'p1',
              type: 'Direct Payment',
              amount: -50,
              createdAt: DateTime(2026, 1, 3)),
          _tx(
              id: 'a1',
              type: 'Adjustment',
              amount: 20,
              createdAt: DateTime(2026, 1, 4)),
        ],
        expenses: const [],
      );
      expect(data.totalDeposits, 500);
      // Money In/Out split by sign, not by transaction name.
      expect(data.moneyIn, 520); // deposit 500 + positive adjustment 20
      expect(data.moneyOut, 150); // |−100| + |−50|
      expect(data.monthlyTrend.first.moneyIn, 520);
      expect(data.monthlyTrend.first.moneyOut, 150);
    });

    test('balance equals the sum of ALL transactions (Dashboard formula)', () {
      final data = computeReportsData(
        now: DateTime(2026, 3, 1),
        categoryNames: const {},
        bills: const [],
        transactions: [
          _tx(
              id: 'd1',
              type: 'Deposit',
              amount: 1000,
              createdAt: DateTime(2026, 1, 5)),
          _tx(
              id: 'd2',
              type: 'Deposit',
              amount: 500,
              createdAt: DateTime(2026, 1, 6)),
          _tx(
              id: 'r1',
              type: 'Reimbursement',
              amount: -300,
              createdAt: DateTime(2026, 1, 7)),
          _tx(
              id: 'p1',
              type: 'Direct Payment',
              amount: -150,
              createdAt: DateTime(2026, 1, 8)),
          _tx(
              id: 'a1',
              type: 'Adjustment',
              amount: 50,
              createdAt: DateTime(2026, 1, 9)),
        ],
        expenses: [
          _expense(
              id: 'e1',
              amount: 300,
              categoryId: 'a',
              status: 'paid',
              createdAt: DateTime(2026, 1, 10)),
        ],
      );

      // 1000 + 500 − 300 − 150 + 50 = 1100 (every transaction, like the
      // Dashboard's Central Account Balance).
      expect(data.balance, 1100);
      // netFlow is a different metric: deposits − paid expenses = 1200.
      expect(data.netFlow, 1200);
      // Money In − Money Out = balance.
      expect(data.moneyIn, 1550); // 1000 + 500 + 50
      expect(data.moneyOut, 450); // |−300| + |−150|
      expect(data.moneyIn - data.moneyOut, data.balance);
    });

    test('money in/out split by sign, so the summary reconciles (future-proof)',
        () {
      final data = computeReportsData(
        now: DateTime(2026, 3, 1),
        categoryNames: const {},
        bills: const [],
        transactions: [
          _tx(
              id: 'd1',
              type: 'Deposit',
              amount: 1000,
              createdAt: DateTime(2026, 1, 5)),
          _tx(
              id: 'p1',
              type: 'Direct Payment',
              amount: -350,
              createdAt: DateTime(2026, 1, 6)),
          _tx(
              id: 'r1',
              type: 'Reimbursement',
              amount: -200,
              createdAt: DateTime(2026, 1, 7)),
          _tx(
              id: 'a1',
              type: 'Adjustment',
              amount: 50,
              createdAt: DateTime(2026, 1, 8)),
          _tx(
              id: 'a2',
              type: 'Adjustment',
              amount: -10,
              createdAt: DateTime(2026, 1, 9)),
        ],
        expenses: const [],
      );

      // The split is purely by amount sign, so new transaction types are
      // picked up automatically without changing the code.
      expect(data.moneyIn, 1050); // 1000 + 50
      expect(data.moneyOut, 560); // 350 + 200 + 10
      expect(data.moneyIn - data.moneyOut, data.balance);
      expect(data.balance, 490);
    });

    test('Money Out breakdown buckets every negative transaction exactly once',
        () {
      final data = computeReportsData(
        now: DateTime(2026, 3, 1),
        categoryNames: const {},
        bills: const [],
        transactions: [
          _tx(
              id: 'r1',
              type: 'Reimbursement',
              amount: -300,
              createdAt: DateTime(2026, 1, 1)),
          _tx(
              id: 'r2',
              type: 'Reimbursement',
              amount: -100,
              createdAt: DateTime(2026, 1, 2)),
          _tx(
              id: 'p1',
              type: 'Direct Payment',
              amount: -150,
              createdAt: DateTime(2026, 1, 3),
              notes: 'Rent'),
          _tx(
              id: 'p2',
              type: 'Direct Payment',
              amount: -50,
              createdAt: DateTime(2026, 1, 4),
              notes: 'Bill: Internet Bill'),
          _tx(
              id: 'a1',
              type: 'Adjustment',
              amount: -10,
              createdAt: DateTime(2026, 1, 5)),
          _tx(
              id: 'd1',
              type: 'Deposit',
              amount: 1000,
              createdAt: DateTime(2026, 1, 6)),
        ],
        expenses: const [],
      );

      final b = data.moneyOutBreakdown;
      expect(b.expenseReimbursements, 400); // 300 + 100
      expect(b.directPayments, 150); // manual direct payment (no "Bill: ")
      expect(b.billPayments, 50); // "Bill: " prefixed
      expect(b.negativeAdjustments, 10);
      expect(b.other, 0);
      // The breakdown total is the single source of truth for Money Out.
      expect(b.total, data.moneyOut);
      expect(data.moneyOut, 610);
      expect(data.moneyIn, 1000);
      expect(data.balance, 390); // 1000 − 610
    });

    test('average monthly expense divides by distinct calendar months', () {
      final data = computeReportsData(
        now: DateTime(2026, 3, 1),
        categoryNames: const {},
        bills: const [],
        transactions: const [],
        expenses: [
          // Jan 2025, Jan 2026 and Feb 2026 are three distinct months.
          _expense(
              id: 'e1',
              amount: 100,
              categoryId: 'a',
              status: 'paid',
              createdAt: DateTime(2025, 1, 10)),
          _expense(
              id: 'e2',
              amount: 100,
              categoryId: 'a',
              status: 'paid',
              createdAt: DateTime(2026, 1, 15)),
          _expense(
              id: 'e3',
              amount: 100,
              categoryId: 'a',
              status: 'paid',
              createdAt: DateTime(2026, 2, 15)),
        ],
      );
      expect(data.totalExpenses, 300);
      expect(data.averageMonthlyExpense, 100);
    });

    test('bills counts split paid vs pending', () {
      final data = computeReportsData(
        now: DateTime(2026, 3, 1),
        categoryNames: const {},
        bills: [
          _bill(id: 'b1', isPaid: true),
          _bill(id: 'b2', isPaid: false),
          _bill(id: 'b3', isPaid: true),
        ],
        transactions: const [],
        expenses: const [],
      );
      expect(data.billsPaid, 2);
      expect(data.billsPending, 1);
    });

    test('empty inputs produce a zeroed report for the current year', () {
      final data = computeReportsData(
        now: DateTime(2026, 3, 1),
        categoryNames: const {},
        bills: const [],
        transactions: const [],
        expenses: const [],
      );
      expect(data.totalExpenses, 0);
      expect(data.totalDeposits, 0);
      expect(data.moneyIn, 0);
      expect(data.moneyOut, 0);
      expect(data.balance, 0);
      expect(data.pendingReimbursements, 0);
      expect(data.largestExpense, 0);
      expect(data.averageMonthlyExpense, 0);
      expect(data.avgExpenseClaim, 0);
      expect(data.avgDeposit, 0);
      expect(data.largestDeposit, 0);
      expect(data.categoryBreakdown, isEmpty);
      expect(data.monthlyTrend, hasLength(3)); // Jan..Mar of the current year.
      expect(
        data.monthlyTrend.every((m) => m.moneyIn == 0 && m.moneyOut == 0),
        isTrue,
      );
    });

    test('all-time report sets allTimeBalance == balance', () {
      final data = computeReportsData(
        now: DateTime(2026, 3, 10),
        categoryNames: const {},
        bills: const [],
        transactions: [
          _tx(
              id: 'd1',
              type: 'Deposit',
              amount: 100,
              createdAt: DateTime(2026, 1, 5)),
          _tx(
              id: 'r1',
              type: 'Reimbursement',
              amount: -40,
              createdAt: DateTime(2026, 1, 2)),
        ],
        expenses: const [],
      );
      // Without a window the report IS all-time, so the two balances coincide.
      expect(data.balance, 60);
      expect(data.allTimeBalance, data.balance);
    });
  });

  group('computeReportsData with a ReportsWindow', () {
    test('scopes totals, the net balance, and the trend to the window', () {
      final now = DateTime(2026, 3, 15);
      final data = computeReportsData(
        now: now,
        categoryNames: const {},
        bills: const [],
        window: resolveReportWindow(
            const ReportFilter(period: ReportPeriod.thisMonth),
            now: now),
        transactions: [
          // Before the window → excluded.
          _tx(
              id: 'd-old',
              type: 'Deposit',
              amount: 1000,
              createdAt: DateTime(2026, 2, 2)),
          _tx(
              id: 'd-in',
              type: 'Deposit',
              amount: 300,
              createdAt: DateTime(2026, 3, 2)),
          _tx(
              id: 'r-in',
              type: 'Reimbursement',
              amount: -100,
              createdAt: DateTime(2026, 3, 5)),
          // Exactly at window.end → excluded (half-open [start, end)).
          _tx(
              id: 'd-boundary',
              type: 'Deposit',
              amount: 50,
              createdAt: DateTime(2026, 4)),
        ],
        expenses: [
          _expense(
              id: 'e-old',
              amount: 500,
              categoryId: 'a',
              status: 'paid',
              createdAt: DateTime(2026, 1, 10)),
          _expense(
              id: 'e-in',
              amount: 200,
              categoryId: 'a',
              status: 'paid',
              createdAt: DateTime(2026, 3, 3)),
          _expense(
              id: 'e-approv',
              amount: 25,
              categoryId: 'a',
              status: 'approved',
              createdAt: DateTime(2026, 3, 4)),
        ],
      );

      // Only the window's records count.
      expect(data.totalDeposits, 300);
      expect(data.moneyIn, 300);
      expect(data.moneyOut, 100);
      expect(data.totalExpenses, 200);
      expect(data.pendingReimbursements, 25);

      // The windowed balance reconciles and equals the period net.
      expect(data.balance, 200); // 300 − 100
      expect(data.moneyIn - data.moneyOut, data.balance);

      // The all-time balance still sees every transaction (Feb 1000 + Apr 50).
      expect(data.allTimeBalance, 1250);

      // Trend is a single March bar, unlabelled by year (single-year span).
      expect(data.monthlyTrend, hasLength(1));
      expect(data.monthlyTrend.first.month, 'Mar');
      expect(data.monthlyTrend.first.moneyIn, 300);
      expect(data.monthlyTrend.first.moneyOut, 100);
    });

    test('a year-boundary window renders the right months with year labels', () {
      final now = DateTime(2026, 1, 15);
      final data = computeReportsData(
        now: now,
        categoryNames: const {},
        bills: const [],
        window: resolveReportWindow(
            const ReportFilter(period: ReportPeriod.last3Months),
            now: now),
        transactions: [
          // Before the window (Oct 2025) → excluded from totals but still in
          // the all-time balance.
          _tx(
              id: 'd-oct',
              type: 'Deposit',
              amount: 9999,
              createdAt: DateTime(2025, 10, 5)),
          _tx(
              id: 'd-nov',
              type: 'Deposit',
              amount: 100,
              createdAt: DateTime(2025, 11, 10)),
          _tx(
              id: 'd-dec',
              type: 'Deposit',
              amount: 200,
              createdAt: DateTime(2025, 12, 10)),
          _tx(
              id: 'd-jan',
              type: 'Deposit',
              amount: 300,
              createdAt: DateTime(2026, 1, 10)),
        ],
        expenses: const [],
      );

      expect(data.moneyIn, 600); // Nov + Dec + Jan
      expect(data.balance, 600);
      expect(data.allTimeBalance, 600 + 9999); // the Oct deposit stays in

      // Nov 2025 → Jan 2026, labelled with two-digit years because the window
      // spans a year boundary.
      expect(data.monthlyTrend, hasLength(3));
      expect(data.monthlyTrend[0].month, 'Nov 25');
      expect(data.monthlyTrend[0].moneyIn, 100);
      expect(data.monthlyTrend[1].month, 'Dec 25');
      expect(data.monthlyTrend[2].month, 'Jan 26');
    });
  });

  group('resolveReportWindow', () {
    final now = DateTime(2026, 3, 15);

    test('all time (default) has no window', () {
      expect(resolveReportWindow(const ReportFilter(), now: now), isNull);
    });

    test('This month is [1st of month, 1st of next month)', () {
      final w = resolveReportWindow(
          const ReportFilter(period: ReportPeriod.thisMonth),
          now: now)!;
      expect(w.start, DateTime(2026, 3));
      expect(w.end, DateTime(2026, 4));
      expect(w.contains(DateTime(2026, 3, 31, 23, 59, 59)), isTrue);
      expect(w.contains(DateTime(2026, 4)), isFalse);
    });

    test('Last 3 months is [1st two months ago, 1st of next month)', () {
      final w = resolveReportWindow(
          const ReportFilter(period: ReportPeriod.last3Months),
          now: now)!;
      expect(w.start, DateTime(2026));
      expect(w.end, DateTime(2026, 4));
    });

    test('This year is [Jan 1, Jan 1 next year)', () {
      final w = resolveReportWindow(
          const ReportFilter(period: ReportPeriod.thisYear),
          now: now)!;
      expect(w.start, DateTime(2026));
      expect(w.end, DateTime(2027));
    });

    test('Custom uses the given half-open range', () {
      final w = resolveReportWindow(
        ReportFilter(
          period: ReportPeriod.custom,
          customStart: DateTime(2026, 1, 15),
          customEnd: DateTime(2026, 2, 20),
        ),
        now: now,
      )!;
      expect(w.start, DateTime(2026, 1, 15));
      expect(w.end, DateTime(2026, 2, 20));
      expect(w.contains(DateTime(2026, 2, 19, 23, 59, 59)), isTrue);
      expect(w.contains(DateTime(2026, 2, 20)), isFalse);
    });

    test('Custom with no dates falls back to all time', () {
      expect(resolveReportWindow(
        const ReportFilter(period: ReportPeriod.custom),
        now: now,
      ), isNull);
    });
  });
}
