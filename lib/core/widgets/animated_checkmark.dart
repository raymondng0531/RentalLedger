import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

/// An animated checkmark that draws itself with a stroke animation.
///
/// Per Emil's philosophy: success states should feel celebrated.
/// The checkmark draws in with ease-out timing (400ms).
/// Use for: form submission success, payment complete, email sent.
class AnimatedCheckmark extends StatefulWidget {
  const AnimatedCheckmark({
    super.key,
    this.size = 80,
    this.color = AppTheme.successGreen,
    this.strokeWidth = 3.5,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _drawAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.success,
    );
    _drawAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppEasing.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drawAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _CheckmarkPainter(
            progress: _drawAnimation.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;

    // Draw circle first (clamped to progress).
    if (progress > 0) {
      final circleProgress = min(1.0, progress * 1.5);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * circleProgress,
        false,
        paint,
      );
    }

    // Draw checkmark (starts after circle reaches ~75%).
    if (progress > 0.6) {
      final checkProgress = (progress - 0.6) / 0.4;

      final startX = center.dx - radius * 0.35;
      final startY = center.dy;

      final midX = center.dx - radius * 0.05;
      final midY = center.dy + radius * 0.3;

      final endX = center.dx + radius * 0.45;
      final endY = center.dy - radius * 0.25;

      // First half of check (down-right).
      if (checkProgress < 0.5) {
        final t = checkProgress * 2;
        final x = startX + (midX - startX) * t;
        final y = startY + (midY - startY) * t;
        canvas.drawLine(Offset(startX, startY), Offset(x, y), paint);
      } else {
        // Full first half.
        canvas.drawLine(Offset(startX, startY), Offset(midX, midY), paint);

        // Second half (up-right).
        final t = (checkProgress - 0.5) * 2;
        final x = midX + (endX - midX) * t;
        final y = midY + (endY - midY) * t;
        canvas.drawLine(Offset(midX, midY), Offset(x, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
