import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../../core/utils/failure_messages.dart';
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
import '../../../../l10n/generated/app_localizations.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../members/domain/entities/house_member_entity.dart';
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
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
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
          tooltip: l10n.navMenu,
        ),
        // Show the current house name clearly with a home icon.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_rounded, size: 18, color: colors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                // The house's own name is user data and stays verbatim; the
                // fallback is the screen's name, so it is localized.
                house?.houseName ?? l10n.navDashboard,
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
              backgroundColor: colors.primary,
              // Badge inherits its label ink from `colorScheme.onError` — a
              // red-tinted role that has nothing to do with this teal badge.
              // Light mode's `onError` is exactly #FFFFFF, so pinning the label
              // to `onPrimary` reproduces the shipped light badge byte for byte
              // while turning the dark badge's label from dark red into the
              // correct deep-teal ink.
              textColor: colors.onPrimary,
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.push(RouteNames.notifications),
            tooltip: l10n.navNotifications,
          ),
          // ── Profile (circular avatar with photo or initial) ──
          Semantics(
            label: l10n.dashboardProfileLabel,
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
                    backgroundColor: colors.primary.withAlpha(25),
                    foregroundImage: (profile?.photoUrl?.isNotEmpty == true)
                        ? NetworkImage(profile!.photoUrl!) as ImageProvider
                        : null,
                    child: (profile?.photoUrl?.isNotEmpty == true)
                        ? null
                        : Text(
                            avatarInitial(profile?.displayName),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
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
    final l10n = AppLocalizations.of(context);
    final message =
        error is Failure
            ? FailureMessages.of(error, l10n)
            : l10n.dashboardLoadError;

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
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

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
                  color: colors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.home_outlined,
                  size: 40,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                // The product name is injected rather than embedded in the
                // message: a proper noun is never translated.
                l10n.dashboardWelcomeTitle(AppConstants.appName),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  l10n.dashboardOnboardingDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push(RouteNames.createHouse),
                icon: const Icon(Icons.add_home_outlined),
                label: Text(l10n.dashboardCreateHouse),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => context.push(RouteNames.joinHouse),
                icon: const Icon(Icons.vpn_key_outlined),
                label: Text(l10n.dashboardJoinWithCode),
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
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    // Category names for the activity cards' category chips.
    final categories =
        ref.watch(categoriesProvider).value ?? const <CategoryEntity>[];
    final categoryMap = {for (final c in categories) c.categoryId: c.name};

    // Member-submitted deposits awaiting the Treasurer: the Treasurer sees
    // every one, a member only their own.
    final house = ref.watch(currentHouseProvider);
    final user = ref.watch(currentUserProvider);
    final depositRequests = visibleDepositRequests(
      ref.watch(pendingDepositRequestsProvider).value ?? const [],
      userId: user?.uid,
      isTreasurer:
          house != null && user != null && house.treasurerId == user.uid,
    );
    final members =
        ref.watch(membersStreamProvider).value ?? const <HouseMemberEntity>[];
    final memberNames = {
      for (final m in members)
        if (m.displayName?.isNotEmpty ?? false) m.userId: m.displayName!,
    };

    return ListView(
      children: [
        const SizedBox(height: 8),

        // ── Central Account Balance ──
        AnimatedEntrance(
          delay: Duration.zero,
          child: ScrollLinkedCompress(
            child: BalanceCard(
              balance: data.balance,
              label: l10n.centralAccountBalance,
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
              label: l10n.dashboardMoneyIn,
              amount: data.monthly.moneyIn,
              icon: Icons.trending_up_rounded,
              iconBackground: colors.success,
              onTap: () => context.go(RouteNames.reports),
            ),
            SummaryCard(
              label: l10n.dashboardMoneyOut,
              amount: data.monthly.moneyOut,
              icon: Icons.trending_down_rounded,
              iconBackground: colors.error,
              onTap: () => context.go(RouteNames.reports),
            ),
            SummaryCard(
              label: l10n.statusPending,
              amount: data.monthly.pendingReimbursements,
              icon: Icons.hourglass_bottom_rounded,
              iconBackground: colors.statusPending,
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
            depositRequests: depositRequests,
            memberNames: memberNames,
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
