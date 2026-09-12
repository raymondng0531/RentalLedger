import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// A frosted "liquid glass" surface — like iOS glass.
///
/// Applies a backdrop blur + translucent fill with a subtle border. Use for
/// cards, sheets, and floating panels.
///
/// The fill, border, and shadow all come from [AppColors], so the surface
/// follows the active theme: a near-opaque white in light mode, a low-alpha
/// white lift in dark mode — a 75%-white card would blow out a dark surface.
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

  /// Strength of the glass fill, as a multiple of the palette's own glass tint
  /// ([AppColors.glassReferenceStrength]). At the default the fill is exactly
  /// the theme's `glassFill`.
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
    final colors = context.colors;
    final radius = BorderRadius.circular(borderRadius);
    // Scale `opacity` against the strength the palette's tint is defined at, so
    // the default (0.75) reproduces that tint exactly in either theme.
    final fillAlpha =
        opacity / AppColors.glassReferenceStrength * colors.glassFill.a;
    final surface = Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.glassFill.withValues(
          alpha: fillAlpha.clamp(0.0, 1.0).toDouble(),
        ),
        borderRadius: radius,
        border: Border.all(
          color: colors.glassBorder,
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
    final shadow = BoxDecoration(
      borderRadius: radius,
      boxShadow: [
        BoxShadow(
          color: colors.glassShadow,
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );

    if (onTap == null) {
      return Container(
        margin: margin,
        decoration: shadow,
        child: glass,
      );
    }

    return Container(
      margin: margin,
      decoration: shadow,
      child: GestureDetector(
        onTap: onTap,
        child: glass,
      ),
    );
  }
}
