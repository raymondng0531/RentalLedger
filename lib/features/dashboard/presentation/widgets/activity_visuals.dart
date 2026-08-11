import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/widgets/activity_card.dart';

/// Shared visual helpers for the Dashboard's activity-ish sections
/// (Pending Items and Recent Activity). Both sections show the same card
/// language — status chips, status colors, per-type icons and amount signs —
/// so these live in ONE place instead of being forked per widget.

/// Status chips for an activity item. The dashboard's Pending Items rows and
/// Recent Activity cards both describe an expense's journey (submitted →
/// approved → paid/rejected), so they share the same chip set.
List<ActivityChip> activityChips(
  String type,
  String title,
  String? status,
  String? categoryId,
  String? paymentSource,
  Map<String, String> categoryMap,
) {
  switch (type) {
    case 'deposit':
      return const [
        ActivityChip(label: 'Deposit', color: AppTheme.successGreen),
        ActivityChip(
          label: 'Central Account',
          color: AppTheme.statusApproved,
        ),
      ];
    case 'reimbursement':
      // A reimbursement IS a paid expense — the title explains the rest.
      return const [
        ActivityChip(label: 'Paid', color: AppTheme.successGreen),
      ];
    case 'payment':
      final isBill = title.startsWith('Bill: ');
      return isBill
          ? const [ActivityChip(label: 'Paid', color: AppTheme.successGreen)]
          : const [
            ActivityChip(
              label: 'Direct Payment',
              color: AppTheme.statusDirectPayment,
            ),
          ];
    case 'expense':
      return [
        ActivityChip(
          label: activityStatusLabel(status),
          color: activityStatusColor(status),
        ),
        if (paymentSource != null)
          ActivityChip(
            label:
                paymentSource == 'personal' ? 'Personal' : 'Central Account',
            color: AppTheme.statusApproved,
          ),
        if (categoryId != null && categoryMap[categoryId] != null)
          ActivityChip(
            label: categoryMap[categoryId]!,
            color: AppTheme.textSecondary,
          ),
      ];
    default:
      return const [];
  }
}

/// Color for an expense's current status (paid/approved/rejected/pending).
Color activityStatusColor(String? status) {
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

/// Human label for an expense's current status.
String activityStatusLabel(String? status) {
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

/// Fallback title when an activity item has no title — describes the action,
/// not the backend event name.
String activityFallbackTitle(String type) {
  switch (type) {
    case 'deposit':
      return 'Deposit';
    case 'payment':
      return 'Direct Payment';
    case 'reimbursement':
      return 'Expense';
    case 'expense':
      return 'Expense';
    default:
      return 'Activity';
  }
}

/// Leading icon + tint for an activity item, by its type.
(IconData, Color) activityVisual(
  String type,
  String? categoryId,
  String? status,
  bool isBill,
) {
  switch (type) {
    case 'deposit':
      return (Icons.savings_outlined, AppTheme.successGreen);
    case 'payment':
      return isBill
          ? (Icons.receipt_long_rounded, AppTheme.successGreen)
          : (Icons.credit_card_rounded, AppTheme.statusDirectPayment);
    case 'reimbursement':
      return (Icons.payments_outlined, AppTheme.successGreen);
    case 'expense':
      return (categoryIcon(categoryId), activityStatusColor(status));
    default:
      return (Icons.swap_horiz_rounded, AppTheme.textSecondary);
  }
}

/// Amount sign + color for an activity item, by its type (deposits come in,
/// payments/reimbursements go out).
(String, Color) activityAmount(String type) {
  switch (type) {
    case 'deposit':
      return ('+', AppTheme.successGreen);
    case 'reimbursement':
    case 'payment':
      return ('-', AppTheme.errorRed);
    default:
      return ('', AppTheme.textSecondary);
  }
}
