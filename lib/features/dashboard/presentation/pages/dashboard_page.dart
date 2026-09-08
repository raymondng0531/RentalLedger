import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../../core/widgets/animated_entrance.dart';
import '../../../../core/widgets/balance_card.dart';
import '../../../../core/widgets/breakpoints.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/scroll_linked_compress.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../features/expenses/domain/entities/category_entity.dart';
import '../../../../features/expenses/presentation/providers/expense_provider.dart';
import '../../../../features/notifications/presentation/providers/notification_provider.dart';
import '../../../../features/notifications/presentation/widgets/notification_toast.dart';
import '../../../../features/settings/presentation/providers/settings_provider.dart';
import '../../../members/presentation/providers/house_provider.dart';
import '../../domain/entities/dashboard_data.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/pending_items_section.dart';
import '../widgets/recent_activity_section.dart';
import '../widgets/summary_card.dart';
import '../widgets/upcoming_bills_section.dart';

/// Main Dashboard screen — the first screen users see after logging in.
///
/// Displays, top to bottom: the fixed financial overview (Central Account
/// Balance + Money In / Money Out / Pending summary cards), then the
/// reorderable section block — Pending Items, Upcoming Bills, Recent
/// Activity. Matches the Figma design.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final house = ref.watch(currentHouseProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final profile = ref.watch(profileProvider);
    // Unread notification count, derived from the realtime notification stream
    // so the badge updates the moment anything is marked read or arrives.
    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(context).openDrawer(),
          tooltip: 'Menu',
        ),
        // Show the current house name clearly with a home icon.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.home_rounded,
              size: 18,
              color: AppTheme.primaryGreen,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                house?.houseName ?? 'Dashboard',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // ── Notifications bell (live unread badge) ──
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: AppTheme.primaryGreen,
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.push(RouteNames.notifications),
            tooltip: 'Notifications',
          ),
          // ── Profile (circular avatar with photo or initial) ──
          Semantics(
            label: 'Profile',
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => context.push(RouteNames.profile),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: AppTheme.primaryGreen.withAlpha(25),
                    foregroundImage: (profile?.photoUrl?.isNotEmpty == true)
                        ? NetworkImage(profile!.photoUrl!) as ImageProvider
                        : null,
                    child: (profile?.photoUrl?.isNotEmpty == true)
                        ? null
                        : Text(
                            avatarInitial(profile?.displayName),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ResponsivePage(
        maxWidth: AppContentWidth.dashboard,
        child: NotificationToastListener(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardDataProvider);
            },
            child: dashboardAsync.when(
              loading: () => _buildLoading(),
              error: (error, _) => _buildError(context, ref, error),
              data: (data) => _buildContent(context, ref, data),
            ),
          ),
        ),
      ),
    );
  }

  // ───── Loading State ─────

  Widget _buildLoading() {
    // Skeleton mirrors the real layout (balance card, summary row, sections,
    // activity rows) shimmering together. The AppBar stays put, so the user
    // is never trapped while data loads.
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: const [
          // ── Central Account Balance card ──
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppConstants.pagePadding,
              vertical: AppConstants.spacingSm,
            ),
            child: SkeletonBox(height: 130, radius: AppConstants.radiusXl),
          ),
          // ── Monthly summary row ──
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppConstants.pagePadding),
            child: Row(
              children: [
                Expanded(
                  child: SkeletonBox(height: 96, radius: AppConstants.radiusLg),
                ),
                SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: SkeletonBox(height: 96, radius: AppConstants.radiusLg),
                ),
                SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: SkeletonBox(height: 96, radius: AppConstants.radiusLg),
                ),
              ],
            ),
          ),
          // ── Upcoming Bills ──
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              AppConstants.spacingXl,
              AppConstants.pagePadding,
              AppConstants.spacingSm,
            ),
            child: SkeletonBox(width: 160, height: 16),
          ),
          SkeletonTile(),
          // ── Recent Activity ──
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppConstants.pagePadding,
              AppConstants.spacingXl,
              AppConstants.pagePadding,
              AppConstants.spacingSm,
            ),
            child: SkeletonBox(width: 160, height: 16),
          ),
          SkeletonTile(),
          SkeletonTile(),
          SkeletonTile(),
        ],
      ),
    );
  }

  // ───── Error State ─────

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    final message =
        error is Failure ? error.message : 'Could not load dashboard.';

    // If no house, show onboarding prompt.
    if (error is NotFoundFailure) {
      return _buildOnboarding(context);
    }

    return ListView(
      children: [
        const SizedBox(height: 48),
        ErrorDisplay(
          message: message,
          onRetry: () => ref.invalidate(dashboardDataProvider),
        ),
      ],
    );
  }

  // ───── Onboarding (no house yet) ─────

  Widget _buildOnboarding(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.home_outlined,
                  size: 40,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to Rental Ledger!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Create or join a house to start tracking expenses.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push(RouteNames.createHouse),
                icon: const Icon(Icons.add_home_outlined),
                label: const Text('Create a House'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => context.push(RouteNames.joinHouse),
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('Join with Code'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───── Content State ─────

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    DashboardData data,
  ) {
    // Category names for the activity cards' category chips.
    final categories =
        ref.watch(categoriesProvider).value ?? const <CategoryEntity>[];
    final categoryMap = {for (final c in categories) c.categoryId: c.name};

    return ListView(
      children: [
        const SizedBox(height: 8),

        // ── Central Account Balance ──
        AnimatedEntrance(
          delay: Duration.zero,
          child: ScrollLinkedCompress(
            child: BalanceCard(
              balance: data.balance,
              label: 'Central Account Balance',
              isLoading: false,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Monthly Summary Row ──
        AnimatedEntrance(
          delay: const Duration(milliseconds: 100),
          child: _buildSummaryRow(
            SummaryCard(
              label: 'Money In',
              amount: data.monthly.moneyIn,
              icon: Icons.trending_up_rounded,
              iconBackground: AppTheme.successGreen,
              onTap: () => context.go(RouteNames.reports),
            ),
            SummaryCard(
              label: 'Money Out',
              amount: data.monthly.moneyOut,
              icon: Icons.trending_down_rounded,
              iconBackground: AppTheme.errorRed,
              onTap: () => context.go(RouteNames.reports),
            ),
            SummaryCard(
              label: 'Pending',
              amount: data.monthly.pendingReimbursements,
              icon: Icons.hourglass_bottom_rounded,
              iconBackground: AppTheme.statusPending,
              onTap: () => context.push(RouteNames.expenses),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Dashboard sections: Pending Items → Upcoming Bills → Recent
        //    Activity ──
        // Composed in this fixed order today. Each section is an independent,
        // self-contained widget, so a future V1.1 preference can reorder them
        // (e.g. Recent Activity first) without rebuilding the Dashboard.
        AnimatedEntrance(
          delay: const Duration(milliseconds: 200),
          child: PendingItemsSection(
            items: data.pendingItems,
            categoryMap: categoryMap,
          ),
        ),
        const AnimatedEntrance(
          delay: Duration(milliseconds: 300),
          child: UpcomingBillsSection(),
        ),
        AnimatedEntrance(
          delay: const Duration(milliseconds: 500),
          child: RecentActivitySection(
            items: data.recentActivity,
            categoryMap: categoryMap,
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSummaryRow(Widget card1, Widget card2, Widget card3) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding),
      child: Row(
        children: [
          Expanded(child: card1),
          const SizedBox(width: 8),
          Expanded(child: card2),
          const SizedBox(width: 8),
          Expanded(child: card3),
        ],
      ),
    );
  }
}
