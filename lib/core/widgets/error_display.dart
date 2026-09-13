import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Error display widget with message and retry button.
///
/// Never exposes technical error details — always shows
/// a user-friendly explanation.
class ErrorDisplay extends StatelessWidget {
  const ErrorDisplay({
    super.key,
    this.message,
    this.onRetry,
  });

  /// Caller-supplied message. When null the widget falls back to the localized
  /// generic message — nullable rather than a defaulted literal so that the
  /// fallback follows the active locale instead of being fixed at construction.
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

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
                color: theme.colorScheme.error.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),

            // ── Message ──
            Text(
              message ?? l10n.errorGenericMessage,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            // ── Retry button ──
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.actionTryAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
