import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Wraps bottom-sheet content so panels spring into place.
///
/// Compose with [showModalBottomSheet]: the sheet's own route animation slides
/// the panel up while this widget springs the content in with a subtle
/// overshoot — legible motion that reads as the panel settling, not just
/// sliding. Reduced-motion users get the content as-is.
class SpringSheet extends StatelessWidget {
  const SpringSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.modal,
      curve: AppEasing.spring,
      builder: (context, t, _) {
        // EaseOutBack overshoots past 1.0, so the panel lifts ~24px then
        // settles slightly past its resting spot before easing back.
        return Opacity(
          opacity: t > 1.0 ? 1.0 : t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 24),
            child: Transform.scale(
              scale: 0.98 + 0.02 * t,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
