import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/vocabulary_labels.dart';
import '../../../../core/widgets/activity_card.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Shared visual helpers for the Dashboard's activity-ish sections
/// (Pending Items and Recent Activity). Both sections show the same card
/// language — status chips, status colors, per-type icons and amount signs —
/// so these live in ONE place instead of being forked per widget.
///
/// These are plain functions with no `BuildContext`, so each takes the active
/// palette explicitly (`colors: context.colors`) rather than reading it from
/// the ambient theme. That keeps them pure and testable while still letting
/// every chip, icon and amount follow the theme.

/// Status chips for an activity item. The dashboard's Pending Items rows and
/// Recent Activity cards both describe an expense's journey (submitted →
/// approved → paid/rejected), so they share the same chip set.
List<ActivityChip> activityChips(
  String type,
  String title,
  String? status,
  String? categoryId,
  String? paymentSource,
  Map<String, String> categoryMap, {
  required AppColors colors,
  required AppLocalizations l10n,
}) {
  switch (type) {
    case 'deposit':
      return [
        ActivityChip(label: l10n.txnTypeDeposit, color: colors.success),
        ActivityChip(
          label: l10n.paymentSourceCentral,
          color: colors.statusApproved,
        ),
      ];
    case 'reimbursement':
      // A reimbursement IS a paid expense — the title explains the rest.
      return [
        ActivityChip(label: l10n.statusPaid, color: colors.success),
      ];
    case 'payment':
      // The stored note still reads "Bill: ", so the prefix test is and stays
      // the literal English one; only the chip's text is localized.
      final isBill = title.startsWith('Bill: ');
      return isBill
          ? [ActivityChip(label: l10n.statusPaid, color: colors.success)]
          : [
              ActivityChip(
                label: l10n.txnTypeDirectPayment,
                color: colors.statusDirectPayment,
              ),
            ];
    case 'expense':
      return [
        ActivityChip(
          label: activityStatusLabel(status, l10n),
          color: activityStatusColor(status, colors: colors),
        ),
        if (paymentSource != null)
          ActivityChip(
            label:
                paymentSource == 'personal'
                    ? l10n.paymentSourcePersonal
                    : l10n.paymentSourceCentral,
            color: colors.statusApproved,
          ),
        if (categoryId != null && categoryMap[categoryId] != null)
          ActivityChip(
            // A default category shows its localized label; a category the user
            // renamed shows the user's own text.
            label:
                VocabularyLabels.categoryOrNull(
                  l10n: l10n,
                  categoryId: categoryId,
                  name: categoryMap[categoryId],
                ) ??
                categoryMap[categoryId]!,
            color: colors.textSecondary,
          ),
      ];
    default:
      return const [];
  }
}

/// Color for an expense's current status (paid/approved/rejected/pending).
Color activityStatusColor(String? status, {required AppColors colors}) {
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

/// Human label for an expense's current status.
///
/// The stored value decides which label is shown; the wording itself comes from
/// the shared vocabulary mapping, so it follows the active language.
String activityStatusLabel(String? status, AppLocalizations l10n) {
  return VocabularyLabels.activityStatus(status, l10n);
}

/// Fallback title when an activity item has no title — describes the action,
/// not the backend event name.
String activityFallbackTitle(String type, AppLocalizations l10n) {
  switch (type) {
    case 'deposit':
      return l10n.txnTypeDeposit;
    case 'payment':
      return l10n.txnTypeDirectPayment;
    case 'reimbursement':
      return l10n.txnTypeExpense;
    case 'expense':
      return l10n.txnTypeExpense;
    default:
      return l10n.txnTypeActivity;
  }
}

/// Leading icon + tint for an activity item, by its type.
(IconData, Color) activityVisual(
  String type,
  String? categoryId,
  String? status,
  bool isBill, {
  required AppColors colors,
}) {
  switch (type) {
    case 'deposit':
      return (Icons.savings_outlined, colors.success);
    case 'payment':
      return isBill
          ? (Icons.receipt_long_rounded, colors.success)
          : (Icons.credit_card_rounded, colors.statusDirectPayment);
    case 'reimbursement':
      return (Icons.payments_outlined, colors.success);
    case 'expense':
      return (
        categoryIcon(categoryId),
        activityStatusColor(status, colors: colors),
      );
    default:
      return (Icons.swap_horiz_rounded, colors.textSecondary);
  }
}

/// Amount sign + color for an activity item, by its type (deposits come in,
/// payments/reimbursements go out).
(String, Color) activityAmount(String type, {required AppColors colors}) {
  switch (type) {
    case 'deposit':
      return ('+', colors.success);
    case 'reimbursement':
    case 'payment':
      return ('-', colors.error);
    default:
      return ('', colors.textSecondary);
  }
}
