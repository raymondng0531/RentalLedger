import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/glass_card.dart';

// AppDurations / AppEasing are exported from app_constants.dart.

/// A compact card for displaying a single dashboard metric.
///
/// Used in the summary row: "This Month In", "This Month Out", "Pending".
/// Follows the Figma design — white card, icon, value, label.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.amount,
    required this.icon,
    this.iconBackground,
    this.isLoading = false,
    this.onTap,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color? iconBackground;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      onTap: onTap,
      // The summary row sits directly on the flat `#F5F5F5` scaffold with
      // nothing painted behind it, so blurring the backdrop is an identity
      // operation — it renders pixel-identically without the blur. Skipping it
      // drops a `saveLayer` + gaussian-blur pass per card per frame inside the
      // dashboard's scrolling list, which is the most expensive thing this
      // screen did on CanvasKit Web.
      blurBackdrop: false,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon ──
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconBackground ?? AppTheme.primaryGreen).withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconBackground ?? AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 12),

            // ── Amount ──
            if (isLoading)
              Container(
                height: 20,
                width: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            else
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: amount),
                duration: AppDurations.standard,
                curve: AppEasing.easeOut,
                builder: (context, value, child) => Text(
                  CurrencyUtils.format(value),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 4),

            // ── Label ──
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
      ),
    );
  }
}
