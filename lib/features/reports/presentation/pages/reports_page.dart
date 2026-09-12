import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/animated_balance.dart';
import '../../../../core/widgets/animated_entrance.dart';
import '../../../../core/widgets/breakpoints.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/skeleton.dart';
import '../providers/reports_provider.dart';

/// Reports screen — analytics, category breakdown, and monthly trends.
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'Menu',
        ),
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () {
              // TODO: Export PDF (V1.0 feature).
              // Compact overlay toast — stays above the bottom action area and
              // never covers the charts below.
              SnackbarUtils.showActionToast(context, 'PDF export coming soon');
            },
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: ResponsivePage(
        maxWidth: AppContentWidth.reports,
        child: reportsAsync.when(
          loading: () => Shimmer(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppConstants.pagePadding),
              children: const [
                // ── At-a-glance summary: In / Out / Balance ──
                Row(
                  children: [
                    Expanded(
                      child: SkeletonBox(
                        height: 88,
                        radius: AppConstants.radiusLg,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: SkeletonBox(
                        height: 88,
                        radius: AppConstants.radiusLg,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: SkeletonBox(
                        height: 88,
                        radius: AppConstants.radiusLg,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 28),
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: SkeletonBox(width: 120, height: 16),
                ),
                // ── Insights grid ──
                Row(
                  children: [
                    Expanded(
                      child: SkeletonBox(height: 64, radius: AppConstants.radiusMd),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: SkeletonBox(height: 64, radius: AppConstants.radiusMd),
                    ),
                  ],
                ),
                SizedBox(height: 28),
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: SkeletonBox(width: 120, height: 16),
                ),
                // ── Category breakdown chart card ──
                SkeletonBox(height: 280, radius: AppConstants.radiusLg),
                SizedBox(height: 28),
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: SkeletonBox(width: 120, height: 16),
                ),
                // ── Monthly trend chart card ──
                SkeletonBox(height: 260, radius: AppConstants.radiusLg),
                SizedBox(height: 32),
              ],
            ),
          ),
          error: (e, _) => ErrorDisplay(
            message: e is Failure ? e.message : 'Could not load reports.',
            onRetry: () => ref.invalidate(reportsProvider),
          ),
          data: (data) => _ReportsContent(data: data),
        ),
      ),
    );
  }
}

class _ReportsContent extends ConsumerStatefulWidget {
  const _ReportsContent({required this.data});
  final ReportsData data;

  @override
  ConsumerState<_ReportsContent> createState() => _ReportsContentState();
}

class _ReportsContentState extends ConsumerState<_ReportsContent> {
  int? _selectedCategory;

  ReportsData get data => widget.data;

  @override
  Widget build(BuildContext context) {
    // The active period filter decides whether the third summary box reads
    // "Net" (a filtered period, In − Out reconciles) or "Current Balance".
    final filter = ref.watch(reportFilterProvider);
    final windowed = resolveReportWindow(filter) != null;

    // A brand-new house has no data yet — show an empty state instead of a
    // row of RM 0.00 boxes. Any money movement (Money In/Out) counts as data,
    // even if no expense claims have been recorded yet.
    final isEmpty = data.moneyIn == 0 &&
        data.moneyOut == 0 &&
        data.categoryBreakdown.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Period filter — always visible so it never scrolls out of reach ──
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            AppConstants.pagePadding,
            AppConstants.pagePadding,
            4,
          ),
          child: _ReportsFilterBar(
            filter: filter,
            onSelect: _applyFilter,
            onPickCustom: _pickCustomRange,
          ),
        ),

        Expanded(
          child: isEmpty
              ? _buildEmptyState(windowed)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.pagePadding,
                    12,
                    AppConstants.pagePadding,
                    AppConstants.pagePadding,
                  ),
                  children: _buildContent(windowed),
                ),
        ),
      ],
    );
  }

  /// The scrollable report body: summary → insights → money-out breakdown →
  /// category breakdown → monthly trend.
  List<Widget> _buildContent(bool windowed) {
    final colors = context.colors;
    // Entrance animations: summary boxes first, insights stagger, then the
    // two chart cards. Keep them subtle (fade + small slide-up, ~400ms).
    const entrance = Duration(milliseconds: 400);

    return [
      // ── At-a-glance summary. All-time: In − Out = Current Balance. Under a
      //    period filter the third box is the period's Net and the true
      //    all-time central-account balance is called out beneath the row. ──
      Row(
        children: [
          Expanded(
            child: AnimatedEntrance(
              duration: entrance,
              child: _SummaryBox(
                label: 'Money In',
                amount: data.moneyIn,
                color: colors.success,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedEntrance(
              delay: const Duration(milliseconds: 60),
              duration: entrance,
              child: _SummaryBox(
                label: 'Money Out',
                amount: data.moneyOut,
                color: colors.error,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedEntrance(
              delay: const Duration(milliseconds: 120),
              duration: entrance,
              child: _SummaryBox(
                label: windowed ? 'Net' : 'Current Balance',
                amount: data.balance,
                color: data.balance >= 0 ? colors.primary : colors.error,
              ),
            ),
          ),
        ],
      ),

      if (windowed) ...[
        const SizedBox(height: 12),
        _AllTimeBalanceNote(amount: data.allTimeBalance),
      ],

      const SizedBox(height: 28),

      // ── Insights ──
      const _SectionTitle('Insights'),
      _InsightsGrid(data: data),

      // ── Where the Money Goes (only when money actually went out) ──
      if (data.moneyOutBreakdown.total > 0) ...[
        const SizedBox(height: 28),
        const _SectionTitle('Where the Money Goes'),
        _MoneyOutCard(data: data),
      ],

      // ── Category Breakdown ──
      const SizedBox(height: 28),
      const _SectionTitle('Category Breakdown'),
      AnimatedEntrance(
        delay: const Duration(milliseconds: 200),
        duration: entrance,
        child: _CategoryBreakdownCard(
          data: data,
          selectedIndex: _selectedCategory,
          onSelect: (i) => setState(() => _selectedCategory = i),
          delay: const Duration(milliseconds: 200),
        ),
      ),

      // ── Monthly Trend ──
      const SizedBox(height: 28),
      const _SectionTitle('Monthly Trend'),
      AnimatedEntrance(
        delay: const Duration(milliseconds: 260),
        duration: entrance,
        child: _MonthlyTrendCard(data: data),
      ),

      const SizedBox(height: 32),
    ];
  }

  Widget _buildEmptyState(bool windowed) {
    if (!windowed) {
      return const EmptyState(
        title: 'No reports yet',
        description:
            'Deposits and expenses will appear here as they are recorded.',
        icon: Icons.bar_chart_outlined,
      );
    }
    // A filter with no matching activity: offer a one-tap way back to all time.
    return EmptyState(
      title: 'Nothing in this period',
      description: 'No deposits, expense claims, or reimbursements fell '
          'inside the selected period.',
      icon: Icons.event_busy_outlined,
      actionLabel: 'Show all time',
      onActionTap: () => _applyFilter(ReportPeriod.allTime),
    );
  }

  void _applyFilter(ReportPeriod period) {
    ref
        .read(reportFilterProvider.notifier)
        .apply(ReportFilter(period: period));
  }

  /// Opens the date-range picker. The chosen inclusive "end day" becomes an
  /// EXCLUSIVE report-window end (one day later), matching History so a range
  /// "to 20 Aug" includes all of 20 Aug.
  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final current = ref.read(reportFilterProvider);

    // Re-open the previously chosen range when it is already the active filter.
    DateTimeRange? initial;
    if (current.period == ReportPeriod.custom &&
        current.customStart != null &&
        current.customEnd != null) {
      initial = DateTimeRange(
        start: current.customStart!,
        end: current.customEnd!.subtract(const Duration(days: 1)),
      );
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: initial,
      helpText: 'Choose a report period',
      saveText: 'Apply',
    );
    if (picked == null || !mounted) return;

    ref.read(reportFilterProvider.notifier).apply(ReportFilter(
          period: ReportPeriod.custom,
          customStart: picked.start,
          customEnd: picked.end.add(const Duration(days: 1)),
        ));
  }
}

// ──────────────────────────────────────────────
// Sections & shared widgets
// ──────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
            ),
            const SizedBox(height: 4),
            // Count-up animation, matching the Dashboard's balance.
            AnimatedBalance(
              balance: amount,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact, balanced grid of insight cards.
///
/// Always two columns (2×2) on phones/tablets; a single row of four on wide
/// desktop windows. Cards keep a fixed height so the section stays compact
/// and every card is the same size.
class _InsightsGrid extends StatelessWidget {
  const _InsightsGrid({required this.data});
  final ReportsData data;

  /// Fixed card height so the grid stays compact and every card is equal.
  static const double _cardHeight = 132;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final highestName = data.highestCategoryName;

    // Each card shares the exact same layout so every number sits in the same
    // position; they just fade/slide in with a small stagger.
    Widget staggered(int index, Widget child) {
      return AnimatedEntrance(
        delay: Duration(milliseconds: 120 + index * 45),
        duration: const Duration(milliseconds: 400),
        child: child,
      );
    }

    final cards = <Widget>[
      staggered(
        0,
        _InsightCard(
          title: 'Highest Expense Category',
          subtitle: highestName,
          amount: highestName == null ? null : data.highestCategoryAmount,
          icon: Icons.category_outlined,
          color: colors.statusApproved,
        ),
      ),
      staggered(
        1,
        _InsightCard(
          title: 'Largest Expense Claim',
          amount: data.largestExpense,
          icon: Icons.receipt_long_outlined,
          color: colors.error,
        ),
      ),
      staggered(
        2,
        _InsightCard(
          title: 'Expense Reimbursements',
          amount: data.totalExpenses,
          icon: Icons.payments_outlined,
          color: colors.warning,
        ),
      ),
      staggered(
        3,
        _InsightCard(
          title: 'Pending Reimbursements',
          amount: data.pendingReimbursements,
          icon: Icons.hourglass_bottom_rounded,
          color: colors.statusPending,
        ),
      ),
      staggered(
        4,
        _InsightCard(
          title: 'Average Monthly Expense',
          amount: data.averageMonthlyExpense,
          icon: Icons.calculate_outlined,
          color: colors.primary,
        ),
      ),
      staggered(
        5,
        _InsightCard(
          title: 'Average Deposit',
          amount: data.avgDeposit,
          icon: Icons.savings_outlined,
          color: colors.success,
        ),
      ),
      staggered(
        6,
        _InsightCard(
          title: 'Largest Deposit',
          amount: data.largestDeposit,
          icon: Icons.trending_up_rounded,
          color: colors.primary,
        ),
      ),
      staggered(
        7,
        _InsightCard(
          title: 'Bills Paid',
          count: data.billsPaid,
          icon: Icons.fact_check_outlined,
          color: colors.success,
        ),
      ),
      staggered(
        8,
        _InsightCard(
          title: 'Bills Pending',
          count: data.billsPending,
          icon: Icons.schedule_rounded,
          color: colors.warning,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Clean, balanced 2-column grid (2 + 2 + 1 for the five cards).
        const columns = 2;
        const crossSpacing = 12.0;
        // Derive the aspect ratio from a fixed card height so the cards never
        // stretch vertically.
        final cellWidth =
            (constraints.maxWidth - crossSpacing * (columns - 1)) / columns;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: crossSpacing,
          childAspectRatio: cellWidth / _cardHeight,
          children: cards,
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    this.amount,
    this.count,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final double? amount;

  /// A plain whole-number value (bill counts) instead of a currency amount.
  final int? count;
  final String? subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: color,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(height: 8),
            // The number is always its own line at the same left position, so
            // long titles can never push the values around. Counts (e.g. bills
            // paid) are plain numbers; money animates and formats as currency.
            if (count != null)
              Text(
                '$count',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              )
            else if (amount != null)
              AnimatedBalance(
                balance: amount!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              )
            else
              Text('—', style: valueStyle),
            const SizedBox(height: 2),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 1),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.colors.textHint,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The true all-time central-account balance, shown under the summary when a
/// period filter turns the third box into the period's Net — so the filtered
/// In/Out/Net numbers are never mistaken for the actual account balance.
class _AllTimeBalanceNote extends StatelessWidget {
  const _AllTimeBalanceNote({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.account_balance_outlined,
          size: 14,
          color: colors.textSecondary,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Central Account balance (all time): '
            '${CurrencyUtils.format(amount)}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

/// Horizontally scrollable period-filter chips. The choice lives in
/// [reportFilterProvider], so picking one recomputes every report below.
class _ReportsFilterBar extends StatelessWidget {
  const _ReportsFilterBar({
    required this.filter,
    required this.onSelect,
    required this.onPickCustom,
  });

  final ReportFilter filter;
  final ValueChanged<ReportPeriod> onSelect;
  final VoidCallback onPickCustom;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final period in ReportPeriod.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(period.label),
                selected: filter.period == period,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) => period == ReportPeriod.custom
                    ? onPickCustom()
                    : onSelect(period),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Where the Money Goes" — what each negative transaction type made up of
/// Money Out, drawn as a stacked bar plus a legend. Only mounted when there
/// is outgoing money, so it is never an empty card.
class _MoneyOutCard extends StatelessWidget {
  const _MoneyOutCard({required this.data});
  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final breakdown = data.moneyOutBreakdown;
    final total = breakdown.total;

    // Buckets in display order; zero buckets are hidden so only money that
    // actually moved is shown.
    final buckets = <({String label, double amount, Color color})>[
      (
        label: 'Expense reimbursements',
        amount: breakdown.expenseReimbursements,
        color: colors.statusApproved,
      ),
      (
        label: 'Direct payments',
        amount: breakdown.directPayments,
        color: colors.warning,
      ),
      (
        label: 'Bill payments',
        amount: breakdown.billPayments,
        color: colors.primary,
      ),
      (
        label: 'Adjustments',
        amount: breakdown.negativeAdjustments,
        color: colors.error,
      ),
      (
        label: 'Other',
        amount: breakdown.other,
        color: colors.textSecondary,
      ),
    ].where((b) => b.amount > 0).toList();

    if (buckets.isEmpty || total <= 0) {
      // Defensive — the caller only mounts this card when total > 0.
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'From ${CurrencyUtils.format(total)} of Money Out',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),

            // ── Stacked bar: each segment ∝ its share of the total ──
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (final b in buckets)
                      Expanded(
                        flex: (b.amount * 1000).round(),
                        child: ColoredBox(color: b.color),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Legend rows ──
            for (final b in buckets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: b.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        b.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      CurrencyUtils.format(b.amount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${((b.amount / total) * 100).toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Category Breakdown
// ──────────────────────────────────────────────

/// Resolves a category's display colour for the ACTIVE theme.
///
/// A category owns its colour in Firestore (`CategoryEntity.color`, an ARGB
/// int) and that stored value is never rewritten — the datastore is untouched
/// by theming. Dark mode therefore has exactly two levers here: leave the
/// stored hue alone, or adapt it at paint time. **This leaves it alone**, and
/// that is a measured decision, not an assumption:
///
/// Against the card each slice is drawn on, the seven stored defaults measure
/// 3.04–6.18:1 on the dark card (`#171B1E`) against 2.80–5.70:1 on the light
/// card (`#FFFFFF`). Dark mode is not a regression for a single one of them —
/// its floor (`household #7C3AED`, 3.04:1) clears WCAG's 3:1 bar for graphical
/// objects, while the shipped light palette has two stored colours *below* that
/// bar (`utilities #F97316` 2.80:1, `maintenance #D97706` 3.19:1). Rewriting
/// stored hues for dark mode would invent new colours to fix a problem dark
/// mode does not have, and would make the same category render as a different
/// colour per theme — which is precisely what Rule 5 forbids.
///
/// The one thing that IS theme-resolved is the [AppColors.categoryFallback]
/// used when a category stores no colour at all: that is a palette value, not
/// stored data, and the palette already carries a dark variant for it.
Color _categoryColor(int? stored, AppColors colors) =>
    Color(stored ?? colors.categoryFallback.toARGB32());

class _CategoryBreakdownCard extends StatefulWidget {
  const _CategoryBreakdownCard({
    required this.data,
    required this.selectedIndex,
    required this.onSelect,
    this.delay = Duration.zero,
  });

  final ReportsData data;
  final int? selectedIndex;
  final ValueChanged<int?> onSelect;

  /// Matches the parent [AnimatedEntrance] delay so the donut starts drawing
  /// in as the card becomes visible.
  final Duration delay;

  @override
  State<_CategoryBreakdownCard> createState() => _CategoryBreakdownCardState();
}

class _CategoryBreakdownCardState extends State<_CategoryBreakdownCard>
    with SingleTickerProviderStateMixin {
  /// Drives the donut "draw-on" (grow open) and the legend fade-in stagger.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  /// The donut grows open over the first half of the sequence.
  late final Animation<double> _grow = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.5, curve: AppEasing.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _legendStart(int i) => (0.55 + i * 0.07).clamp(0.0, 0.9);
  double _legendEnd(int i) => (_legendStart(i) + 0.12).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final breakdown = widget.data.categoryBreakdown;
    final total =
        breakdown.fold<double>(0, (sum, c) => sum + c.amount);
    final selectedIndex = widget.selectedIndex;
    final selected = (selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < breakdown.length)
        ? breakdown[selectedIndex]
        : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding + 2),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // A tiny floor keeps fl_chart from ever seeing a zero-sum pie.
            final grow = max(_grow.value, 0.001);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Donut chart (grows open on entry) ──
                SizedBox(
                  height: 190,
                  child: PieChart(
                    PieChartData(
                      sections: List.generate(breakdown.length, (i) {
                        final c = breakdown[i];
                        final color = _categoryColor(c.color, colors);
                        final isSelected = selectedIndex == i;
                        return PieChartSectionData(
                          value: c.amount * grow,
                          color: (selectedIndex == null || isSelected)
                              ? color
                              : color.withAlpha(70),
                          // Slightly larger when selected — fl_chart tweens
                          // this radius change smoothly.
                          radius: isSelected ? 58 : 52,
                          title: '',
                          // Inert, and deliberately left literal: the slice
                          // title above is the empty string, so fl_chart lays
                          // out a zero-width TextPainter and paints nothing —
                          // no glyph ever takes this colour in either mode.
                          // There is no "ink on a slice" token, and inventing
                          // one for text that is never drawn would be palette
                          // expansion with no rendering change. Slices are
                          // identified by the legend and the selected-detail
                          // panel below, not by on-slice labels.
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          badgeWidget: null,
                        );
                      }),
                      sectionsSpace: 2,
                      centerSpaceRadius: 34,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (event is FlTapUpEvent) {
                            // Tapping the chart center or outside a slice
                            // reports -1 — clear the selection instead of
                            // indexing into sections[-1].
                            final index = response
                                ?.touchedSection
                                ?.touchedSectionIndex;
                            widget.onSelect(
                                index != null && index >= 0 ? index : null);
                          }
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Selected category detail ──
                AnimatedSwitcher(
                  duration: AppDurations.standard,
                  child: selected != null
                      ? Container(
                          key: ValueKey(selected.name),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _categoryColor(selected.color, colors)
                                .withAlpha(18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _categoryColor(selected.color, colors)
                                  .withAlpha(70),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _categoryColor(selected.color, colors),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  selected.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                CurrencyUtils.format(selected.amount),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                total > 0
                                    ? '${((selected.amount / total) * 100).toStringAsFixed(0)}%'
                                    : '0%',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          key: const ValueKey('hint'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'Tap a slice to see details',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colors.textHint),
                          ),
                        ),
                ),

                const SizedBox(height: 8),

                // ── Legend (fades in one-by-one after the donut draws) ──
                ...List.generate(breakdown.length, (i) {
                  final c = breakdown[i];
                  final percent = total > 0
                      ? ((c.amount / total) * 100).toStringAsFixed(0)
                      : '0';
                  final opacity = Interval(
                    _legendStart(i),
                    _legendEnd(i),
                    curve: AppEasing.easeOut,
                  ).transform(_controller.value);
                  return _LegendRow(
                    name: c.name,
                    amount: c.amount,
                    percent: percent,
                    color: _categoryColor(c.color, colors),
                    isSelected: selectedIndex == i,
                    opacity: opacity,
                    onTap: () => widget.onSelect(selectedIndex == i ? null : i),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.name,
    required this.amount,
    required this.percent,
    required this.color,
    required this.isSelected,
    required this.opacity,
    required this.onTap,
  });

  final String name;
  final double amount;
  final String percent;
  final Color color;
  final bool isSelected;

  /// Fade-in progress for the entry stagger (0→1).
  final double opacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: opacity,
      child: FractionalTranslation(
        // Small slide-up as the row fades in during the entry stagger.
        translation: Offset(0, 0.15 * (1 - opacity)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: AppDurations.standard,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              // `Colors.transparent` is the "paint no highlight" sentinel, not
              // a palette colour — it stays transparent in both modes.
              color: isSelected ? color.withAlpha(14) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: AppDurations.standard,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Text(
                  CurrencyUtils.format(amount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '$percent%',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Monthly Trend
// ──────────────────────────────────────────────

class _MonthlyTrendCard extends StatelessWidget {
  const _MonthlyTrendCard({required this.data});
  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxY = data.monthlyTrend.fold<double>(
      0,
      (m, e) => max(m, max(e.moneyIn, e.moneyOut)),
    );
    final yMax = maxY * 1.25;
    final interval = _niceInterval(yMax);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Legend ──
            Row(
              children: [
                _LegendDot(color: colors.success, label: 'Money In'),
                const SizedBox(width: 16),
                _LegendDot(color: colors.error, label: 'Money Out'),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 210,
              child: _buildTrendChart(context, data, interval, yMax),
            ),
          ],
        ),
      ),
    );
  }

  /// Monthly trend bar chart — bars grow from 0 to full height on entry
  /// (chart growth, ~650ms). Reduced motion renders the full chart instantly.
  Widget _buildTrendChart(
    BuildContext context,
    ReportsData data,
    double interval,
    double yMax,
  ) {
    final colors = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: MediaQuery.disableAnimationsOf(context) ? 1.0 : 0.0,
        end: 1.0,
      ),
      duration: const Duration(milliseconds: 650),
      curve: AppEasing.easeOut,
      builder: (context, growth, _) => BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: yMax,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              // The tooltip floats over the card it belongs to, so it is
              // filled with the elevation step above a surface rather than a
              // hardcoded white. It separates from the dark card by 1.11:1
              // plus its `divider` hairline — measurably MORE separation than
              // the shipped light mode gets, where a white tooltip on a white
              // card relies on the hairline alone.
              getTooltipColor: (_) => colors.surfaceElevated,
              tooltipRoundedRadius: 10,
              tooltipBorder: BorderSide(color: colors.divider),
              maxContentWidth: 200,
              // Keep the tooltip fully inside the chart: when a bar is near an
              // edge, fl_chart shifts the tooltip to the other side (or
              // inwards) instead of letting it get clipped.
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final m = data.monthlyTrend[groupIndex];
                return BarTooltipItem(
                  '${m.month}\n',
                  TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                  children: [
                    TextSpan(
                      text:
                          'Money In   ${CurrencyUtils.format(m.moneyIn)}\n',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text:
                          'Money Out ${CurrencyUtils.format(m.moneyOut)}\n',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: 'Net  ${CurrencyUtils.format(m.net)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: m.net >= 0 ? colors.success : colors.error,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.monthlyTrend.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      data.monthlyTrend[i].month,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  return Text(
                    _shortAmount(value),
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.textSecondary,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colors.divider,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(data.monthlyTrend.length, (i) {
            final m = data.monthlyTrend[i];
            return BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                // Money in (positive transactions).
                BarChartRodData(
                  toY: m.moneyIn * growth,
                  color: colors.success,
                  width: 8,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                  ),
                ),
                // Money out (negative transactions).
                BarChartRodData(
                  toY: m.moneyOut * growth,
                  color: colors.error,
                  width: 8,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    topRight: Radius.circular(3),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  /// A compact Y-axis label (e.g. "1.2K", "500", "0").
  String _shortAmount(double value) {
    if (value >= 1000) {
      final v = value / 1000;
      return v == v.roundToDouble()
          ? '${v.round()}K'
          : '${v.toStringAsFixed(1)}K';
    }
    return value.round().toString();
  }

  /// A "nice" axis interval (1/2/5 × 10^n) so labels stay readable.
  double _niceInterval(double maxY) {
    if (maxY <= 0) return 1;
    final raw = maxY / 4;
    final exp = (log(raw) / ln10).floor();
    final base = pow(10, exp).toDouble();
    final normalized = raw / base;
    final nice = normalized <= 1
        ? 1.0
        : normalized <= 2
            ? 2.0
            : normalized <= 5
                ? 5.0
                : 10.0;
    return nice * base;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
