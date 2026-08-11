import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_utils.dart';

/// Animated count-up for plain integer values (e.g. "5 bills paid").
///
/// Same duration/easing as [AnimatedBalance] for consistency, but renders the
/// number without a currency symbol.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.count,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final int count;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: count.toDouble()),
      duration: AppDurations.standard,
      curve: AppEasing.easeOut,
      builder: (context, value, child) {
        return Text(
          value.round().toString(),
          style: style,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}

/// Displays a balance amount with a counting animation when the value changes.
///
/// Per Emil: numbers changing on a dashboard should feel alive, not jump.
/// Uses ease-out for a natural settling effect (200ms).
class AnimatedBalance extends StatelessWidget {
  const AnimatedBalance({
    super.key,
    required this.balance,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final double balance;
  final TextStyle? style;

  /// Optional single-line constraints (e.g. inside compact stat cards).
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: balance),
      duration: AppDurations.standard,
      curve: AppEasing.easeOut,
      builder: (context, value, child) {
        return Text(
          CurrencyUtils.format(value),
          style: style,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}
