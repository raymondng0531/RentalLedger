import 'dart:ui';

import 'package:flutter/material.dart';

/// A frosted "liquid glass" surface — like iOS glass.
///
/// Applies a backdrop blur + translucent white fill with a subtle border.
/// Use for cards, sheets, and floating panels.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.margin,
    this.onTap,
    this.opacity = 0.75,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final glass = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((opacity * 255).round()),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withAlpha(120),
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: glass,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: glass,
      ),
    );
  }
}
