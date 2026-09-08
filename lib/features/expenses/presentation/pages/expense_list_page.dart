import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/widgets/animated_entrance.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../features/members/domain/entities/house_member_entity.dart';
import '../../../../features/members/presentation/providers/house_provider.dart';
import '../providers/expense_provider.dart';
import '../widgets/expense_card.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/expense_entity.dart';

/// Expense List screen — all house expenses with status filters.
class ExpenseListPage extends ConsumerStatefulWidget {
  const ExpenseListPage({super.key});

  @override
  ConsumerState<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends ConsumerState<ExpenseListPage> {
  String? _statusFilter;

  static const _statuses = [null, 'pending', 'approved', 'paid', 'rejected'];
  static const _labels = ['All', 'Pending', 'Approved', 'Paid', 'Rejected'];

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expenseListProvider(_statusFilter));
    final categoriesAsync = ref.watch(categoriesProvider);
    final membersAsync = ref.watch(membersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        // No back button — Expenses is a primary bottom-nav tab, so it uses
        // the drawer menu just like Home, History, and Reports.
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'Menu',
        ),
        title: const Text('Expenses'),
      ),
      body: ResponsivePage(
        // maxWidth omitted — defaults to AppContentWidth.detail (800).
        child: Column(
          children: [
            // ── Status filter tabs ──
            // A Material TabBar provides the sliding teal pill indicator for
            // free — tapping animates the pill to the active filter.
            SizedBox(
              height: 52,
              child: DefaultTabController(
                length: _statuses.length,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  indicatorPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  unselectedLabelColor: AppTheme.textPrimary,
                  onTap: (i) => setState(() => _statusFilter = _statuses[i]),
                  tabs: [for (final label in _labels) Tab(text: label)],
                ),
              ),
            ),
            const Divider(height: 1),

            // ── List (crossfades when the active filter changes) ──
            Expanded(
              child: AnimatedSwitcher(
                duration: AppDurations.standard,
                switchInCurve: AppEasing.easeOut,
                switchOutCurve: AppEasing.accelerate,
                child: KeyedSubtree(
                  key: ValueKey(_statusFilter),
                  child: expensesAsync.when(
                    loading: () => const Shimmer(child: SkeletonListBody()),
                    error: (e, _) => ErrorDisplay(
                      message:
                          e is Failure ? e.message : 'Could not load expenses.',
                      onRetry: () => ref.invalidate(
                        expenseListProvider(_statusFilter),
                      ),
                    ),
                    data: (expenses) => _buildResults(
                      context,
                      expenses,
                      categoriesAsync.value ?? const <CategoryEntity>[],
                      membersAsync.value ?? const <HouseMemberEntity>[],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the expense result list for the active filter.
  Widget _buildResults(
    BuildContext context,
    List<ExpenseEntity> expenses,
    List<CategoryEntity> categories,
    List<HouseMemberEntity> members,
  ) {
    if (expenses.isEmpty) {
      return EmptyState(
        title: 'No expenses',
        description: _statusFilter == null
            ? 'Submit an expense to get started.'
            : 'No $_statusFilter expenses yet.',
        icon: Icons.receipt_long_outlined,
        actionLabel: 'Add Expense',
        onActionTap: () => context.push(RouteNames.addExpense),
      );
    }

    final categoryNames = {for (final c in categories) c.categoryId: c.name};
    // Resolve purchaser display names — never show a UID.
    final nameMap = {
      for (final m in members)
        m.userId: (m.displayName?.isNotEmpty == true
            ? m.displayName!
            : 'Unknown Member'),
    };

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: staggeredEntrance(
        context,
        expenses,
        (context, expense) => ExpenseCard(
          expense: expense,
          categoryName: categoryNames[expense.categoryId],
          memberName: nameMap[expense.purchasedBy],
          onTap: () => context.push(
            RouteNames.expenseDetails.replaceFirst(
              ':expenseId',
              expense.expenseId,
            ),
          ),
        ),
        keyOf: (e) => e.expenseId,
      ),
    );
  }
}
