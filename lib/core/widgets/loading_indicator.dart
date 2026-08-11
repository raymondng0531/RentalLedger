import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Reusable loading indicator with optional message.
///
/// Use for full-screen loading states. For skeleton loaders
/// inside cards, use [SkeletonCard] instead.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.message,
    this.fullScreen = false,
  });

  final String? message;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppTheme.primaryGreen,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (fullScreen) {
      return Center(child: content);
    }
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(child: content),
    );
  }
}

/// Skeleton card placeholder for dashboard loading states.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.height = 80,
    this.width,
  });

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
