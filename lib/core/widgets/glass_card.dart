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
    this.blurBackdrop = true,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double opacity;

  /// Whether to blur whatever is painted behind the card.
  ///
  /// The blur is only meaningful when there is something behind the card to
  /// blur — a gradient, an image, or another surface. Over a flat opaque
  /// backdrop (the app's `#F5F5F5` scaffold) blurring a uniform colour is an
  /// identity operation, so dropping it renders pixel-identically.
  ///
  /// It is not free, though: [BackdropFilter] forces a `saveLayer` plus a
  /// gaussian-blur pass every time its layer repaints. On Flutter Web
  /// (CanvasKit) that is among the most expensive operations available, and
  /// inside a scrolling list it re-runs on every scroll frame. Pass `false`
  /// wherever the backdrop is a flat colour to remove that cost for no
  /// visible change.
  final bool blurBackdrop;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final surface = Container(
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
    );
    final glass = ClipRRect(
      borderRadius: radius,
      child: blurBackdrop
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: surface,
            )
          : surface,
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
