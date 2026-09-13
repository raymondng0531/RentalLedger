import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/failure_messages.dart';
import '../../../../core/utils/vocabulary_labels.dart';
import '../../../../core/widgets/animated_entrance.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../features/members/domain/entities/house_member_entity.dart';
import '../../../../features/members/presentation/providers/house_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
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

  /// The **stored** status values the tabs filter on — never translated.
  static const _statuses = [null, 'pending', 'approved', 'paid', 'rejected'];

  /// Display labels for [_statuses], resolved per build so a runtime language
  /// switch relabels the tabs.
  static List<String> _statusLabels(AppLocalizations l10n) => [
        l10n.expenseFilterAll,
        l10n.statusPending,
        l10n.statusApproved,
        l10n.statusPaid,
        l10n.statusRejected,
      ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final expensesAsync = ref.watch(expenseListProvider(_statusFilter));
    final categoriesAsync = ref.watch(categoriesProvider);
    // All records (active + inactive former members): an expense card still
    // needs the purchaser's name after they leave the house.
    final membersAsync = ref.watch(allMembersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        // No back button — Expenses is a primary bottom-nav tab, so it uses
        // the drawer menu just like Home, History, and Reports.
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: l10n.expenseMenuTooltip,
        ),
        title: Text(l10n.navExpenses),
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
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  indicatorPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  // Not a palette colour: "draw no rule under the tabs" — the
                  // explicit Divider below owns that line in both modes.
                  dividerColor: Colors.transparent,
                  // Ink on the sliding teal pill. `onPrimary` is white in light
                  // mode and deep teal in dark, where the pill's teal lightens.
                  labelColor: colors.onPrimary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  unselectedLabelColor: colors.textPrimary,
                  onTap: (i) => setState(() => _statusFilter = _statuses[i]),
                  tabs: [
                    for (final label in _statusLabels(l10n)) Tab(text: label),
                  ],
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
                      message: e is Failure
                          ? FailureMessages.of(e, l10n)
                          : l10n.expenseListLoadError,
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
    final l10n = AppLocalizations.of(context);
    if (expenses.isEmpty) {
      return EmptyState(
        title: l10n.emptyNoExpenses,
        description: _statusFilter == null
            ? l10n.expenseEmptyDescription
            : l10n.expenseEmptyFiltered(
                VocabularyLabels.statusBadge(_statusFilter, l10n),
              ),
        icon: Icons.receipt_long_outlined,
        actionLabel: l10n.actionAddExpense,
        onActionTap: () => context.push(RouteNames.addExpense),
      );
    }

    final categoryNames = {for (final c in categories) c.categoryId: c.name};
    // Resolve purchaser display names — never show a UID.
    final nameMap = {
      for (final m in members)
        m.userId: (m.displayName?.isNotEmpty == true
            ? m.displayName!
            : l10n.expenseUnknownMember),
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
