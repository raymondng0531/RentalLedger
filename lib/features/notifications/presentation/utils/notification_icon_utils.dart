import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Maps a notification [type] string to its brand icon + colour.
///
/// Shared by the notification list tile ([NotificationTile]) and the floating
/// notification toast ([NotificationToastListener]) so both surfaces render
/// the same iconography for the same notification — never two sources of truth
/// for what an "Expense Approved" notification looks like.
///
/// Takes the palette explicitly (`colors: context.colors`) because it is a
/// plain function with no `BuildContext` to read the ambient theme from.
(IconData, Color) notificationIconFor(
  String type, {
  required AppColors colors,
}) {
  switch (type) {
    case 'Expense Submitted':
      return (Icons.receipt_long_outlined, colors.warning);
    case 'Expense Approved':
      return (Icons.check_circle_outline, colors.success);
    case 'Expense Rejected':
      return (Icons.cancel_outlined, colors.error);
    case 'Payment Completed':
      return (Icons.wallet_outlined, colors.statusApproved);
    case 'Deposit Recorded':
      return (Icons.arrow_downward_rounded, colors.success);
    case 'Deposit Submitted':
      return (Icons.savings_outlined, colors.warning);
    case 'Deposit Approved':
      return (Icons.check_circle_outline, colors.success);
    case 'Deposit Rejected':
      return (Icons.cancel_outlined, colors.error);
    case 'Reimbursement Reminder':
      return (Icons.notifications_active_outlined, colors.warning);
    default:
      return (Icons.notifications_outlined, colors.textSecondary);
  }
}
