import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// A colored badge that displays the status of an expense or transaction.
///
/// Color mapping (from the UI spec):
/// - Pending → Orange
/// - Approved → Blue
/// - Paid → Green
/// - Rejected → Red
/// - Direct Payment → Purple
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.size = StatusBadgeSize.small,
  });

  final String status;
  final StatusBadgeSize size;

  /// Returns the color for a given status string.
  static Color colorFor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppTheme.statusPending;
      case 'approved':
        return AppTheme.statusApproved;
      case 'paid':
      case 'completed':
        return AppTheme.statusPaid;
      case 'rejected':
        return AppTheme.statusRejected;
      case 'direct payment':
        return AppTheme.statusDirectPayment;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    final fontSize = switch (size) {
      StatusBadgeSize.small => 11.0,
      StatusBadgeSize.medium => 12.0,
      StatusBadgeSize.large => 14.0,
    };
    final padding = switch (size) {
      StatusBadgeSize.small => const EdgeInsets.symmetric(
        horizontal: 8, vertical: 3,
      ),
      StatusBadgeSize.medium => const EdgeInsets.symmetric(
        horizontal: 10, vertical: 4,
      ),
      StatusBadgeSize.large => const EdgeInsets.symmetric(
        horizontal: 12, vertical: 6,
      ),
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum StatusBadgeSize { small, medium, large }
