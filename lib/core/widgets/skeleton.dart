import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_constants.dart';

/// Premium skeleton-placeholder primitives.
///
/// The loading pattern is: wrap a layout of static [SkeletonBox]es (and
/// [SkeletonTile]s) in a single [Shimmer], which sweeps one soft highlight
/// across the whole layout — one animation controller per skeleton screen.
/// This is cheap (no per-box controllers) and calm (no strong moving
/// gradients).
///
/// Both widgets respect the platform "reduce motion" preference: when
/// animations are disabled the placeholder renders as a flat static box —
/// functional, just not shimmering.

/// A static rounded placeholder block. Wrap a group of these in [Shimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.circular = false,
    this.color,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circular;

  /// Overrides the placeholder tint. Defaults to the theme's `skeletonBase` —
  /// null rather than a const default because the tint is theme-dependent and
  /// a default parameter value must be a compile-time constant.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? context.colors.skeletonBase,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Sweeps a soft highlight across a layout of static skeleton blocks.
///
/// Uses [ShaderMask] + a single repeating [AnimationController], so the whole
/// skeleton screen shimmers together rather than each box pulsing alone.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;

  /// Overrides the resting tint. Defaults to the theme's `skeletonBase`.
  final Color? baseColor;

  /// Overrides the sweep highlight. Defaults to the theme's
  /// `skeletonHighlight`.
  final Color? highlightColor;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery must be read here (not in initState), and the controller
    // must only start once — otherwise it restarts on every dependency change.
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion: render the flat placeholder, no sweep.
    if (_reducedMotion) return widget.child;

    final colors = context.colors;
    final baseColor = widget.baseColor ?? colors.skeletonBase;
    final highlightColor = widget.highlightColor ?? colors.skeletonHighlight;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Sweep the highlight band across the child from left to right.
        final shift = 3.0 * _progress.value - 1.5;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(shift, 0),
              end: Alignment(shift + 1.5, 0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A shimmer-friendly list-row placeholder: leading circle, two text lines
/// and a right-aligned amount block — the same silhouette as [ActivityCard]
/// and the ListTiles across the app. Wrap in [Shimmer].
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key, this.showTrailing = true});

  final bool showTrailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const SkeletonBox(width: 40, height: 40, radius: 12),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 150, radius: 7),
                SizedBox(height: 8),
                SkeletonBox(width: 200, height: 11, radius: 6),
                SizedBox(height: 8),
                SkeletonBox(width: 96, height: 10, radius: 5),
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: 12),
            const SkeletonBox(width: 64, height: 16),
          ],
        ],
      ),
    );
  }
}

/// A scrollable, non-interactive stack of [SkeletonTile]s — used when a whole
/// list screen is loading (History, Expenses, Notifications, Members). Wrap in
/// a [Shimmer]. The real AppBar/filter bar stays put above it, so the user is
/// never trapped while data loads.
class SkeletonListBody extends StatelessWidget {
  const SkeletonListBody({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: List.generate(itemCount, (_) => const SkeletonTile()),
    );
  }
}

/// Detail-screen skeleton: a hero amount block followed by label/value rows —
/// mirrors the amount header + info sections on Expense/Bill details. Wrap in a
/// [Shimmer].
class SkeletonDetailBody extends StatelessWidget {
  const SkeletonDetailBody({super.key, this.heroHeight = 120});

  final double heroHeight;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SkeletonBox(
            height: heroHeight,
            radius: AppConstants.radiusXl,
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: SkeletonBox(width: 140, height: 16),
        ),
        const SkeletonTile(),
        const SkeletonTile(),
        const SkeletonTile(),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: SkeletonBox(width: 120, height: 16),
        ),
        const SkeletonTile(),
        const SkeletonTile(),
      ],
    );
  }
}
