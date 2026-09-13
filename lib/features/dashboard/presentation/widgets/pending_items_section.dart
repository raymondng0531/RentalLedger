import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firestore_constants.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/activity_item.dart';
import 'activity_visuals.dart';

/// Pending Items — the open expense claims (submitted + approved) that are
/// still waiting on the Treasurer. The dashboard's Pending summary card sums
/// the FULL open-claims list ([items], one source of truth); this section
/// stays compact by showing the 5 most recent, and a claim moves through it
/// in real time (submitted → appears, approved → label flips, paid/rejected →
/// disappears).
class PendingItemsSection extends StatelessWidget {
  const PendingItemsSection({
    super.key,
    required this.items,
    required this.categoryMap,
  });

  /// All open claims (submitted + approved) — the full list, not pre-capped.
  final List<ActivityItem> items;

  /// Category id → name, for the category chips.
  final Map<String, String> categoryMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final items = this.items.take(5).toList();

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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.dashboardPendingItems,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (items.isNotEmpty)
                TextButton.icon(
                  onPressed: () => context.push(RouteNames.expenses),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(l10n.actionViewAll),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),

        if (items.isEmpty)
          // Compact empty state — the section stays small when nothing is
          // waiting on the Treasurer.
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppConstants.pagePadding,
            ),
            child: ListTile(
              leading: Icon(Icons.task_alt_rounded, color: colors.textHint),
              title: Text(l10n.dashboardPendingItemsEmpty),
              subtitle: Text(l10n.dashboardPendingItemsEmptyDescription),
            ),
          )
        else
          // Rebuilt straight from the stream (not ImplicitAnimatedList) so an
          // in-place status change re-renders the tile immediately, no reload.
          ..._buildItemCards(context, items),
      ],
    );
  }

  List<Widget> _buildItemCards(
    BuildContext context,
    List<ActivityItem> items,
  ) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return [
      for (final item in items)
        Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppConstants.pagePadding,
            vertical: 3,
          ),
          child: InkWell(
            onTap: () => context.push(
              RouteNames.expenseDetails.replaceFirst(':expenseId', item.id),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Category icon ──
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _statusColor(item.status, colors: colors)
                          .withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      categoryIcon(item.categoryId),
                      size: 20,
                      color: _statusColor(item.status, colors: colors),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ── Title + amount, waiting label, chips ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              CurrencyUtils.format(item.amount, localeCode: l10n.localeName),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _waitingLabel(item.status, l10n),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _statusColor(item.status, colors: colors),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: activityChips(
                            'expense',
                            item.title,
                            item.status,
                            item.categoryId,
                            item.paymentSource,
                            categoryMap,
                            colors: context.colors,
                            l10n: l10n,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: colors.textHint),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  /// The waiting label shown under an open claim's title.
  ///
  /// The stored status decides which of the two labels applies; the wording
  /// comes from the active locale.
  String _waitingLabel(String? status, AppLocalizations l10n) {
    if (status == FirestoreConstants.statusApproved) {
      return l10n.dashboardWaitingForReimbursement;
    }
    return l10n.dashboardWaitingForApproval;
  }

  /// Status color for an open claim: approved blue, otherwise pending amber.
  ///
  /// Kept local rather than delegating to `activityStatusColor` from
  /// `activity_visuals.dart`: this section only ever renders *open* claims, so
  /// its rule is "approved, or still waiting on the Treasurer" — a two-state
  /// rule, not the shared helper's four-state one. The two agree for every
  /// status this section can receive.
  Color _statusColor(String? status, {required AppColors colors}) {
    if (status == FirestoreConstants.statusApproved) {
      return colors.statusApproved;
    }
    return colors.statusPending;
  }
}
