import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Maps a notification [type] string to its brand icon + colour.
///
/// Shared by the notification list tile ([NotificationTile]) and the floating
/// notification toast ([NotificationToastListener]) so both surfaces render
/// the same iconography for the same notification — never two sources of truth
/// for what an "Expense Approved" notification looks like.
(IconData, Color) notificationIconFor(String type) {
  switch (type) {
    case 'Expense Submitted':
      return (Icons.receipt_long_outlined, AppTheme.warningOrange);
    case 'Expense Approved':
      return (Icons.check_circle_outline, AppTheme.successGreen);
    case 'Expense Rejected':
      return (Icons.cancel_outlined, AppTheme.errorRed);
    case 'Payment Completed':
      return (Icons.wallet_outlined, AppTheme.statusApproved);
    case 'Deposit Recorded':
      return (Icons.arrow_downward_rounded, AppTheme.successGreen);
    case 'Reimbursement Reminder':
      return (Icons.notifications_active_outlined, AppTheme.warningOrange);
    default:
      return (Icons.notifications_outlined, AppTheme.textSecondary);
  }
}
