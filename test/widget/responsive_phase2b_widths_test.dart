import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/features/expenses/domain/entities/category_entity.dart';
import 'package:rental_ledger/features/expenses/domain/entities/expense_entity.dart';
import 'package:rental_ledger/features/expenses/presentation/pages/add_expense_page.dart';
import 'package:rental_ledger/features/expenses/presentation/pages/expense_list_page.dart';
import 'package:rental_ledger/features/expenses/presentation/providers/expense_provider.dart';
import 'package:rental_ledger/features/history/presentation/pages/history_page.dart';
import 'package:rental_ledger/features/history/presentation/providers/history_provider.dart';
import 'package:rental_ledger/features/members/domain/entities/house_member_entity.dart';
import 'package:rental_ledger/features/members/presentation/providers/house_provider.dart';
import 'package:rental_ledger/features/reports/presentation/pages/reports_page.dart';
import 'package:rental_ledger/features/reports/presentation/providers/reports_provider.dart';

/// Sweeps the Phase 2B responsive pages (Expenses, Add Expense, History,
/// Reports) across the widths the Web/PWA responsive work targets (phones,
/// tablets, desktops, large monitors) and fails if any page overflows at any
/// width. The breakpoints sit at 600/840/1200, so these widths exercise each
/// class: compact (360, 414), medium (600, 768, 834), expanded (840, 1024), and
/// extraLarge (1280, 1440, 1920).
///
/// Every page is pumped in its **populated** data state (real cards, form
/// fields, history tiles, charts) so genuine layout overflows are exercised —
/// the empty/error states carry no content to overflow.
///
/// Expense Details (and its Edit Expense dialog) are NOT swept here: the page
/// imports `receipt_image.dart`, whose approved web implementation
/// unconditionally imports `dart:js_interop` / `dart:ui_web` / `package:web`,
/// which the VM test platform cannot compile. Those screens are verified via
/// the local web run instead (resize the browser through the widths).

const _widths = <double>[360, 414, 600, 768, 834, 840, 1024, 1280, 1440, 1920];

// ── Sample domain data ──────────────────────────────────────────────
// DateTimes can't be const, so these are top-level finals.

final _now = DateTime(2026, 8);

final _expense = ExpenseEntity(
  expenseId: 'e1',
  houseId: 'h1',
  purchasedBy: 'user1',
  title: 'Weekly groceries',
  description: 'Fruit, vegetables and rice',
  categoryId: 'food',
  amount: 42.5,
  receiptUrl: 'https://example.com/receipt.jpg',
  paymentSource: 'personal',
  // status defaults to 'pending' (the editable, member-ownable milestone).
  createdAt: _now,
  displayName: 'Alice',
);

const _categories = <CategoryEntity>[
  CategoryEntity(categoryId: 'rent', name: 'Rent', icon: 'home', color: 0xFF2563EB),
  CategoryEntity(categoryId: 'utilities', name: 'Utilities', icon: 'bolt', color: 0xFFF97316),
  CategoryEntity(categoryId: 'food', name: 'Food', icon: 'restaurant', color: 0xFF16A34A),
  CategoryEntity(categoryId: 'household', name: 'Household', icon: 'inventory', color: 0xFF7C3AED),
  CategoryEntity(categoryId: 'maintenance', name: 'Maintenance', icon: 'build', color: 0xFFD97706),
  CategoryEntity(categoryId: 'internet', name: 'Internet', icon: 'wifi', color: 0xFF0891B2),
  CategoryEntity(categoryId: 'other', name: 'Other', icon: 'more_horiz', color: 0xFF64748B),
];

final _member = HouseMemberEntity(
  memberId: 'm1',
  houseId: 'h1',
  userId: 'user1',
  joinedAt: _now,
  displayName: 'Alice',
);

final _event = HistoryEvent(
  id: 'ev1',
  type: HistoryEventType.expenseSubmitted,
  amount: -42.5,
  date: _now,
  refId: 'e1',
  title: 'Weekly groceries',
  categoryId: 'food',
  status: 'pending',
  userId: 'user1',
  paymentSource: 'personal',
);

const _reportsData = ReportsData(
  totalExpenses: 350,
  totalDeposits: 800,
  moneyIn: 800,
  moneyOut: 649,
  balance: 151,
  highestCategoryName: 'Rent',
  highestCategoryAmount: 200,
  largestExpense: 150,
  averageMonthlyExpense: 116.67,
  avgExpenseClaim: 175,
  avgDeposit: 400,
  largestDeposit: 600,
  billsPaid: 1,
  billsPending: 2,
  categoryBreakdown: [
    CategorySpending(name: 'Food', amount: 100, color: 0xFF16A34A),
    CategorySpending(name: 'Rent', amount: 200, color: 0xFF2563EB),
    CategorySpending(name: 'Utilities', amount: 50, color: 0xFFF97316),
  ],
  monthlyTrend: [
    MonthlyComparison(month: 'Aug', moneyIn: 800, moneyOut: 649),
  ],
);

// ── Provider overrides per page ─────────────────────────────────────
// Each page is given its data state directly, so no page touches Firebase.

final _expenseListOverrides = <Override>[
  expenseListProvider.overrideWith((ref, arg) => Stream.value([_expense])),
  categoriesProvider.overrideWith((ref) async => _categories),
  // Expense cards resolve the purchaser's name from ALL member records
  // (active + inactive former members), so this page uses the all-members
  // name source, not the active-only roster.
  allMembersStreamProvider.overrideWith((ref) => Stream.value([_member])),
];

final _addExpenseOverrides = <Override>[
  categoriesProvider.overrideWith((ref) async => _categories),
];

final _historyOverrides = <Override>[
  historyProvider.overrideWith((ref, arg) => Stream.value([_event])),
  categoriesProvider.overrideWith((ref) async => _categories),
  // History tiles resolve actor/payer names from ALL member records (active +
  // inactive former members), so this page uses the all-members name source.
  allMembersStreamProvider.overrideWith((ref) => Stream.value([_member])),
];

final _reportsOverrides = <Override>[
  reportsProvider.overrideWith((ref) => Stream.value(_reportsData)),
];

Future<void> _pumpPage(
  WidgetTester tester,
  double width,
  Widget page,
  List<Override> overrides,
) async {
  // Tall enough that lazily-built ListViews (Reports) build every section, so
  // hidden overflows in deep cards are caught too.
  await tester.binding.setSurfaceSize(Size(width, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: page),
    ),
  );
  await tester.pump(); // Stream.value emits on the next microtask → data state.
  await tester.pumpAndSettle(); // Finish entrance animations.
}

void main() {
  final pages = <String, (Widget, List<Override>)>{
    'Expenses': (const ExpenseListPage(), _expenseListOverrides),
    'Add Expense': (const AddExpensePage(), _addExpenseOverrides),
    'History': (const HistoryPage(), _historyOverrides),
    'Reports': (const ReportsPage(), _reportsOverrides),
  };

  for (final entry in pages.entries) {
    for (final width in _widths) {
      testWidgets('${entry.key} at ${width}px', (tester) async {
        await _pumpPage(
          tester,
          width,
          entry.value.$1,
          entry.value.$2,
        );
        expect(tester.takeException(), isNull,
            reason: '${entry.key} overflowed at $width px');
      });
    }
  }
}
