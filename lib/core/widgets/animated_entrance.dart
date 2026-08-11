import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// A subtle fade + slide entrance animation for widgets entering the screen.
///
/// Per Emil's design engineering principles:
/// - ease-out for responsive, natural motion
/// - start from a small translateY (never from scale(0))
/// - optional stagger via [delay]
class AnimatedEntrance extends StatefulWidget {
  const AnimatedEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.08),
    this.duration,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration? duration;

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? AppDurations.pageTransition,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: AppEasing.easeOut,
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(curve);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect "reduce motion": content appears instantly, no entrance.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// Wraps a list of items in sequentially-delayed [AnimatedEntrance]s so they
/// fade/slide in one-by-one on first appearance (30-60ms stagger per item).
///
/// Each child is keyed by [keyOf], so items that stay present keep their state
/// and do NOT re-animate when the list updates — only genuinely new items
/// animate. Satisfies "animate newly inserted items only, never the page".
List<Widget> staggeredEntrance<T>(
  BuildContext context,
  List<T> items,
  Widget Function(BuildContext context, T item) itemBuilder, {
  required Object Function(T item) keyOf,
  Duration stagger = AppDurations.stagger,
  Duration duration = const Duration(milliseconds: 250),
  Duration maxStagger = const Duration(milliseconds: 400),
}) {
  return [
    for (var i = 0; i < items.length; i++)
      AnimatedEntrance(
        key: ValueKey(keyOf(items[i])),
        delay: Duration(
          milliseconds: min(
            i * stagger.inMilliseconds,
            maxStagger.inMilliseconds,
          ),
        ),
        duration: duration,
        child: itemBuilder(context, items[i]),
      ),
  ];
}
