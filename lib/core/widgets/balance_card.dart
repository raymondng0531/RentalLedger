import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import 'animated_balance.dart';

/// A prominent card that displays a financial balance with animated counting.
///
/// Used on the Dashboard and Central Account screens.
/// Designed to match the Figma mockup — green card with
/// large white balance text.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    this.label = 'Central Account Balance',
    this.onActionTap,
    this.actionLabel,
    this.actionIcon,
    this.isLoading = false,
  });

  final double balance;
  final String label;
  final VoidCallback? onActionTap;
  final String? actionLabel;
  final IconData? actionIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.pagePadding,
        vertical: AppConstants.spacingSm,
      ),
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white.withAlpha(200),
              ),
            ),
            const SizedBox(height: 8),

            // ── Animated balance ──
            if (isLoading)
              _ShimmerLoader()
            else
              AnimatedBalance(
                balance: balance,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),

            if (actionLabel != null && onActionTap != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onActionTap,
                  icon: Icon(actionIcon ?? Icons.add),
                  label: Text(actionLabel!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Simple shimmer placeholder for loading state.
class _ShimmerLoader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(60),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
