import 'package:flutter/material.dart';

import 'press_scale.dart';

/// Empty state widget with illustration, title, description, and optional action.
///
/// Every list screen should use this when there is no data to display.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon ──
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon ?? Icons.inbox_outlined,
                size: 40,
                color: theme.colorScheme.primary.withAlpha(150),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ──
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            // ── Description ──
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // ── Action ──
            if (actionLabel != null && onActionTap != null) ...[
              const SizedBox(height: 24),
              PressScale(
                child: FilledButton(
                  onPressed: onActionTap,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
