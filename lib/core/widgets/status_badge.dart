import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

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

  /// Returns the color for a given status string, from the **light** palette.
  ///
  /// Kept as the fixed light-value lookup because it is public API that callers
  /// and tests depend on. The widget itself renders through [resolve] so it
  /// follows the active theme; prefer [resolve] wherever a palette is
  /// available.
  static Color colorFor(String status) => resolve(status, AppColors.light);

  /// Brightness-aware counterpart of [colorFor]: the same mapping, read from
  /// the supplied palette. Dark mode's status colours are lightened so they
  /// stay legible on a dark surface.
  static Color resolve(String status, AppColors colors) {
    switch (status.toLowerCase()) {
      case 'pending':
        return colors.statusPending;
      case 'approved':
        return colors.statusApproved;
      case 'paid':
      case 'completed':
        return colors.statusPaid;
      case 'rejected':
        return colors.statusRejected;
      case 'direct payment':
        return colors.statusDirectPayment;
      default:
        return colors.statusNeutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = resolve(status, context.colors);
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
