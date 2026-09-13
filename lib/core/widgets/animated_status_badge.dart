import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import 'status_badge.dart';

/// A [StatusBadge] that animates when the status changes.
///
/// When the status flips (Pending → Approved → Paid / Rejected) the badge
/// cross-fades with a subtle scale pop — keeping the state transition
/// legible without being distracting.
class AnimatedStatusBadge extends StatelessWidget {
  const AnimatedStatusBadge({
    super.key,
    required this.status,
    this.label,
    this.size = StatusBadgeSize.small,
  });

  /// The **stored** status value. Also keys the animation, so the badge still
  /// cross-fades on a real status change and not on a language change.
  final String status;

  /// Localized display text. Defaults to [status] when null.
  final String? label;

  final StatusBadgeSize size;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppDurations.standard,
      switchInCurve: AppEasing.easeOut,
      switchOutCurve: AppEasing.accelerate,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: AppEasing.easeOut),
            ),
            child: child,
          ),
        );
      },
      child: StatusBadge(
        key: ValueKey(status),
        status: status,
        label: label,
        size: size,
      ),
    );
  }
}
