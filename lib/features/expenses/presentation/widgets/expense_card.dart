import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/expense_entity.dart';

/// A card displaying an expense summary in lists.
///
/// Uses the same visual language as the History timeline:
/// rounded backgroundLight card, category icon, title, "Member • Date • Time"
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
    final statusColor = _statusColor(expense.status);
    final (String sign, Color amountColor) = _amountStyle(expense.status);
    final member = memberName ?? 'Unknown Member';
    final subtitle =
        '$member • '
        '${DateFormatUtils.formatDateShort(expense.createdAt)} • '
        '${DateFormatUtils.formatTime(expense.createdAt)}';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.pagePadding,
        vertical: 4,
      ),
      elevation: 0,
      color: AppTheme.backgroundLight,
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
                            color: AppTheme.textSecondary,
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
                    '$sign${CurrencyUtils.format(expense.amount)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
              // ── Chips ──
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: _chips()),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _chips() {
    final chips = <Widget>[
      // Status chip — crossfades with a subtle scale when the expense's
      // status flips live (Submitted → Approved → Paid / Rejected).
      AnimatedSwitcher(
        duration: AppDurations.standard,
        switchInCurve: AppEasing.easeOut,
        switchOutCurve: AppEasing.accelerate,
        child: _chip(
          _statusLabel(expense.status),
          _statusColor(expense.status),
          key: ValueKey(expense.status),
        ),
      ),
      _chip(
        expense.isPersonal ? 'Personal' : 'Central Account',
        AppTheme.statusApproved,
      ),
    ];
    if (categoryName != null) {
      chips.add(_chip(categoryName!, AppTheme.textSecondary));
    }
    return chips;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return AppTheme.successGreen;
      case 'approved':
        return AppTheme.statusApproved;
      case 'rejected':
        return AppTheme.errorRed;
      default:
        return AppTheme.statusPending;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Submitted';
    }
  }

  /// Paid expenses show money out (−, red); others are neutral.
  (String, Color) _amountStyle(String status) {
    switch (status) {
      case 'paid':
        return ('-', AppTheme.errorRed);
      default:
        return ('', AppTheme.textSecondary);
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
