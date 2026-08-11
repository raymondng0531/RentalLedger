import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/activity_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/implicit_animated_list.dart';
import '../../domain/entities/activity_item.dart';
import 'activity_visuals.dart';

/// Recent Activity — the latest household transactions, expenses, deposits and
/// reimbursements, newest first. Uses the same card language as the History
/// timeline, capped at the 5 most recent for a lightweight overview.
class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({
    super.key,
    required this.items,
    required this.categoryMap,
  });

  /// The full recent-activity feed (already newest-first); the section shows
  /// the 5 most recent.
  final List<ActivityItem> items;

  /// Category id → name, for the category chips.
  final Map<String, String> categoryMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Keep the dashboard a lightweight overview — the latest 5 only.
    // The ImplicitAnimatedList diffs by key, so a new item slides in at the
    // top and the 6th (oldest) slides out, in real time.
    final recent = items.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            AppConstants.spacingLg,
            AppConstants.pagePadding,
            AppConstants.spacingSm,
          ),
          child: Text(
            'Recent Activity',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        if (recent.isEmpty)
          const EmptyState(
            title: 'No activity yet',
            description:
                'Transactions, expenses, and deposits will appear here.',
            icon: Icons.receipt_long_outlined,
          )
        else ...[
          ImplicitAnimatedList<ActivityItem>(
            items: recent,
            itemKey: (item) => item.id,
            initialStagger: AppDurations.stagger,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemBuilder: (context, item) => _activityCard(context, item),
          ),
          // Full-width link to the full History timeline (default "All" filter).
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.pagePadding,
              vertical: AppConstants.spacingSm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push(RouteNames.history),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('See All Activity'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Builds a compact [ActivityCard] from a dashboard activity item, using the
  /// same card language as the History timeline.
  ActivityCard _activityCard(BuildContext context, ActivityItem item) {
    final type = item.type;

    // Titles must describe the action, not the backend event name.
    var title = item.title;
    if (type == 'reimbursement') {
      title = title.replaceFirst(RegExp(r'^Reimbursement:\s*'), '');
    } else if (type == 'payment') {
      title = title.replaceFirst(RegExp(r'^Bill:\s*'), '');
    }
    title = title.trim();
    if (title.isEmpty) title = activityFallbackTitle(type);

    // Member name: strip the datasource's "by " prefix, then shorten.
    final member =
        (item.subtitle ?? '').replaceFirst(RegExp(r'^by\s*'), '').trim();
    final memberName =
        (member.isEmpty || member == 'a member') ? 'Unknown Member' : member;
    final dateLine =
        '${DateFormatUtils.formatDateShort(item.date)} • '
        '${DateFormatUtils.formatTime(item.date)}';
    final subtitle = '${shortMemberName(memberName)} • $dateLine';

    final isBill = type == 'payment' && item.title.startsWith('Bill: ');
    final (IconData icon, Color iconColor) = activityVisual(
      type,
      item.categoryId,
      item.status,
      isBill,
    );
    final (String sign, Color amountColor) = activityAmount(type);

    return ActivityCard(
      title: title,
      subtitle: subtitle,
      amount: item.amount,
      amountSign: sign,
      amountColor: amountColor,
      icon: icon,
      iconColor: iconColor,
      chips: activityChips(
        type,
        item.title,
        item.status,
        item.categoryId,
        item.paymentSource,
        categoryMap,
      ),
    );
  }
}
