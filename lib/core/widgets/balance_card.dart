import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../l10n/generated/app_localizations.dart';
import 'animated_balance.dart';

/// A prominent card that displays a financial balance with animated counting.
///
/// Used on the Dashboard and Central Account screens.
/// Designed to match the Figma mockup — green card with
/// large `onPrimary` balance text.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    this.label,
    this.onActionTap,
    this.actionLabel,
    this.actionIcon,
    this.isLoading = false,
  });

  final double balance;

  /// Caller-supplied label. When null the widget falls back to the localized
  /// "Central Account Balance" — nullable rather than a defaulted literal so
  /// that the fallback follows the active locale.
  final String? label;
  final VoidCallback? onActionTap;
  final String? actionLabel;
  final IconData? actionIcon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Everything inside this card sits on the primary fill, so its foreground
    // is `onPrimary` rather than a literal white — identical in light mode
    // (#FFFFFF), dark ink in dark mode where the primary is lightened.
    final onPrimary = context.colors.onPrimary;

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
              label ?? AppLocalizations.of(context).centralAccountBalance,
              style: theme.textTheme.labelLarge?.copyWith(
                color: onPrimary.withAlpha(200),
              ),
            ),
            const SizedBox(height: 8),

            // ── Animated balance ──
            if (isLoading)
              _ShimmerLoader(color: onPrimary)
            else
              AnimatedBalance(
                balance: balance,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: onPrimary,
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
                    foregroundColor: onPrimary,
                    // Matches the old `Colors.white38` (0x62FFFFFF).
                    side: BorderSide(color: onPrimary.withAlpha(98)),
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
  const _ShimmerLoader({required this.color});

  /// The card's foreground colour — the placeholder block is a wash of it.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 180,
      decoration: BoxDecoration(
        color: color.withAlpha(60),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
