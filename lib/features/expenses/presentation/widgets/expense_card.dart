import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/vocabulary_labels.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/expense_entity.dart';

/// A card displaying an expense summary in lists.
///
/// Uses the same visual language as the History timeline:
/// rounded muted card, category icon, title, "Member • Date • Time"
/// and status / payment-method / category chips.
class ExpenseCard extends StatelessWidget {
  const ExpenseCard({
    super.key,
    required this.expense,
    this.onTap,
    this.categoryName,
    this.memberName,
  });

  final ExpenseEntity expense;
  final VoidCallback? onTap;

  /// Display name of the category (falls back to the raw id while loading).
  final String? categoryName;

  /// Resolved purchaser display name — never the raw UID.
  final String? memberName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final statusColor = _statusColor(expense.status, colors: colors);
    final (String sign, Color amountColor) =
        _amountStyle(expense.status, colors: colors);
    final member = memberName ?? l10n.expenseUnknownMember;
    final subtitle =
        '$member • '
        '${DateFormatUtils.formatDateShort(expense.createdAt, l10n.localeName)} • '
        '${DateFormatUtils.formatTime(expense.createdAt, l10n.localeName)}';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.pagePadding,
        vertical: 4,
      ),
      elevation: 0,
      color: colors.surfaceMuted,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // ── Category icon ──
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      categoryIcon(expense.categoryId),
                      size: 20,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ── Title + member • date • time ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ── Amount ──
                  Text(
                    '$sign${CurrencyUtils.format(expense.amount, localeCode: l10n.localeName)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
              // ── Chips ──
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: _chips(colors, l10n)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _chips(AppColors colors, AppLocalizations l10n) {
    final chips = <Widget>[
      // Status chip — crossfades with a subtle scale when the expense's
      // status flips live (Submitted → Approved → Paid / Rejected).
      AnimatedSwitcher(
        duration: AppDurations.standard,
        switchInCurve: AppEasing.easeOut,
        switchOutCurve: AppEasing.accelerate,
        child: _chip(
          VocabularyLabels.activityStatus(expense.status, l10n),
          _statusColor(expense.status, colors: colors),
          key: ValueKey(expense.status),
        ),
      ),
      _chip(
        expense.isPersonal
            ? l10n.paymentSourcePersonal
            : l10n.paymentSourceCentral,
        colors.statusApproved,
      ),
    ];
    // A seeded default category shows its localized label; a renamed one shows
    // the user's own text.
    final category = VocabularyLabels.categoryOrNull(
      l10n: l10n,
      categoryId: expense.categoryId,
      name: categoryName,
    );
    if (category != null) {
      chips.add(_chip(category, colors.textSecondary));
    }
    return chips;
  }

  /// Status ink for an expense.
  ///
  /// Kept local rather than delegating to `activityStatusColor` from the
  /// dashboard: the two rules agree today, but they live in different feature
  /// layers and the expense card is the one the Treasurer reads before
  /// approving, so it is not coupled to the dashboard's feed styling.
  Color _statusColor(String status, {required AppColors colors}) {
    switch (status) {
      case 'paid':
        return colors.success;
      case 'approved':
        return colors.statusApproved;
      case 'rejected':
        return colors.error;
      default:
        return colors.statusPending;
    }
  }

  /// Paid expenses show money out (−, red); others are neutral.
  (String, Color) _amountStyle(String status, {required AppColors colors}) {
    switch (status) {
      case 'paid':
        return ('-', colors.error);
      default:
        return ('', colors.textSecondary);
    }
  }

  Widget _chip(String label, Color color, {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
