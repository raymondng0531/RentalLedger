import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_utils.dart';

/// A single activity card — the shared visual language for the Dashboard's
/// Recent Activity and the History timeline.
///
/// Layout (identical everywhere):
/// [icon]  Title                    -RM 84.50
///         Member • 6 Aug 2026 • 5:03 PM
///         [chip] [chip]
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.amount = 0,
    required this.amountSign,
    required this.amountColor,
    required this.icon,
    required this.iconColor,
    this.amountLabel,
    this.chips = const [],
    this.onTap,
  });

  final String title;
  final String subtitle;

  /// Signed amount (positive = money in, negative = money out).
  ///
  /// Not required, and ignored when [amountLabel] is supplied — a row that has
  /// no money amount to show passes [amountLabel] instead of a placeholder
  /// number.
  final double amount;

  /// Display sign prefix: '+' | '-' | '' (status milestones are neutral).
  final String amountSign;

  /// The amount's colour. `null` keeps the theme's own text colour — the
  /// default an unstyled amount gets, which is what a bill row wants when its
  /// amount is a plain magnitude rather than money in or out.
  final Color? amountColor;

  /// Replaces the amount column's TEXT, for a row whose amount is not a
  /// number the app can state.
  ///
  /// Bill History uses it for amountless reminder bills: the established
  /// treatment across the app is the word "Reminder" (see the Dashboard's
  /// Upcoming Bills) rather than a fabricated "RM 0.00", because "no amount
  /// set" and "RM 0.00" are different facts. [amount] and [amountSign] are
  /// then unused, and the caller supplies the matching [amountColor].
  ///
  /// Defaults to null — every existing caller renders exactly as before.
  final String? amountLabel;

  final IconData icon;
  final Color iconColor;

  /// Pre-built chips (e.g. [ActivityChip]s). Only relevant ones.
  final List<Widget> chips;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.pagePadding,
        vertical: 4,
      ),
      elevation: 0,
      color: AppTheme.backgroundLight,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                // Amount pinned to the top-right so it aligns across cards.
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withAlpha(22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Stronger amount, matching the Dashboard summary cards.
                  Text(
                    amountLabel ??
                        '$amountSign${CurrencyUtils.format(amount.abs())}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
              // Chips align under the title column — never under the icon.
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 52), // 40 icon + 12 gap
                  child: Wrap(spacing: 6, runSpacing: 6, children: chips),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small labelled chip used on activity cards.
class ActivityChip extends StatelessWidget {
  const ActivityChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Title-cases an all-caps display name ("RAYMOND NG" → "Raymond Ng") while
/// leaving properly-cased names untouched.
String formatMemberName(String name) {
  if (name.isEmpty || name != name.toUpperCase()) return name;
  return name
      .toLowerCase()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// A compact member name for list cards — title-cased and limited to the
/// first two words ("Raymond Ng Chian Quan / Upm" → "Raymond Ng").
/// The full name remains available on the detail page.
String shortMemberName(String name) {
  final cleaned = formatMemberName(name);
  final words =
      cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return words.take(2).join(' ');
}
