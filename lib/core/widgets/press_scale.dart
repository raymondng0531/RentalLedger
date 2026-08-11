import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Scales its child down slightly while pressed, springing back on release.
///
/// Flutter equivalent of CSS `:active { transform: scale(0.97); }` — press
/// feedback in 100-160ms per Emil's rules. Unlike [AnimatedPressable] (which
/// takes over the tap gesture), this uses raw [Listener] pointer events, so it
/// composes with any child — including Material buttons that own their own tap
/// gesture and ink ripple — and never competes for the tap. Reduced-motion
/// aware: no-op when the platform requests reduced motion.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.buttonPress,
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: AppEasing.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(_) => _controller.forward();
  void _up(_) => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    // Respect "reduce motion": render normally, no press scale.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
