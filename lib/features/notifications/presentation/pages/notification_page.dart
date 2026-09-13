import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/animated_entrance.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../domain/entities/notification_entity.dart';
import '../utils/notification_icon_utils.dart';
import '../providers/notification_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Notifications screen — list of system notifications grouped by time.
///
/// Groups: Today, This Week, Earlier
/// Unread notifications are highlighted with a blue dot.
class NotificationPage extends ConsumerWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: l10n.actionBack,
        ),
        title: Text(l10n.navNotifications),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_outlined),
            onPressed: () {
              final user = ref.read(currentUserProvider);
              if (user != null) {
                // The Firestore write flows straight into the realtime stream,
                // which re-renders every tile and the unread count — no manual
                // refresh, no provider invalidation.
                ref.read(notificationDataSourceProvider).markAllAsRead(user.uid);
              }
              SnackbarUtils.showSuccess(context, l10n.notifAllMarkedRead);
            },
            tooltip: l10n.actionMarkAllRead,
          ),
        ],
      ),
      body: ResponsivePage(
        // maxWidth omitted — defaults to AppContentWidth.detail (800).
        child: notificationsAsync.when(
          loading: () => const Shimmer(child: SkeletonListBody(itemCount: 8)),
          error: (e, _) => ErrorDisplay(
            message: l10n.notifLoadFailed,
            onRetry: () => ref.invalidate(notificationsStreamProvider),
          ),
          data: (notifications) => _buildList(context, ref, notifications),
        ),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<NotificationEntity> items) {
    final l10n = AppLocalizations.of(context);
    if (items.isEmpty) {
      return EmptyState(
        title: l10n.emptyNoNotifications,
        description: l10n.notifEmptyDescription,
        icon: Icons.notifications_none_rounded,
      );
    }

    // Group by time period.
    final now = DateTime.now();
    final today = <NotificationEntity>[];
    final thisWeek = <NotificationEntity>[];
    final earlier = <NotificationEntity>[];

    for (final n in items) {
      final diff = now.difference(n.createdAt);
      if (diff.inDays == 0) {
        today.add(n);
      } else if (diff.inDays < 7) {
        thisWeek.add(n);
      } else {
        earlier.add(n);
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (today.isNotEmpty)
          _buildNotificationGroup(
            context,
            ref,
            '${l10n.timeToday}, ${DateFormatUtils.formatDateShort(now, l10n.localeName)}',
            today,
          ),
        if (thisWeek.isNotEmpty)
          _buildNotificationGroup(context, ref, l10n.timeThisWeek, thisWeek),
        if (earlier.isNotEmpty)
          _buildNotificationGroup(context, ref, l10n.timeEarlier, earlier),
      ],
    );
  }

  /// Builds a section (header + staggered tiles) for a group of notifications.
  ///
  /// Tiles are rebuilt straight from the stream rather than diffed by key.
  /// [ImplicitAnimatedList] only animates keys that appear/disappear and never
  /// rebuilds an item whose key stays the same — so a mark-as-read toggle
  /// (same notification, new isRead) left the tile stale until the page was
  /// reloaded. Rebuilding from the stream makes the read/unread styling go
  /// live the moment the Firestore write lands, while genuinely new
  /// notifications still stagger in via [staggeredEntrance].
  Widget _buildNotificationGroup(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<NotificationEntity> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, title),
        ...staggeredEntrance<NotificationEntity>(
          context,
          items,
          (context, n) => _NotificationTile(
            notification: n,
            onTap: () {
              // Fire-and-forget: the snapshots() stream emits the updated doc,
              // so the tile and the unread count refresh with no reload.
              ref
                  .read(notificationDataSourceProvider)
                  .markAsRead(n.notificationId);
            },
          ),
          keyOf: (n) => n.notificationId,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final NotificationEntity notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final iconData = notificationIconFor(notification.type, colors: colors);
    // The unread wash is a primary tint at a fixed 8/255 — the shipped V1.0
    // recipe, kept verbatim because alpha compositing already scales with the
    // ground it lands on: it measures 1.039:1 against the light scaffold and
    // 1.040:1 against the dark one, i.e. dark mode is not a regression. The
    // load-bearing unread signals are the dot and the bold title, and BOTH
    // strengthen in dark mode (dot 3.96:1 light → 7.70:1 dark). `transparent`
    // for a read row is the "paint no fill" sentinel, not a colour.
    final bgColor = notification.isRead
        ? Colors.transparent
        : colors.primary.withAlpha(8);

    return Material(
      color: bgColor,
      child: InkWell(
        onTap: notification.isRead ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icon ──
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconData.$2.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Icon(iconData.$1, size: 20, color: iconData.$2),
              ),
              const SizedBox(width: 12),

              // ── Content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!notification.isRead) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  notification.isRead ? FontWeight.w400 : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormatUtils.formatRelative(notification.createdAt, l10n)}'
                      ' · '
                      '${DateFormatUtils.formatDateTime(notification.createdAt, l10n.localeName)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textHint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
