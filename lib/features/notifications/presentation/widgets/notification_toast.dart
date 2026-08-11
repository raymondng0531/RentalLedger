import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../providers/notification_provider.dart';
import '../utils/notification_icon_utils.dart';

/// Watches for new notifications and shows a floating toast that
/// auto-dismisses after a few seconds. No navigation or extra taps needed.
class NotificationToastListener extends ConsumerStatefulWidget {
  const NotificationToastListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationToastListener> createState() =>
      _NotificationToastListenerState();
}

class _NotificationToastListenerState
    extends ConsumerState<NotificationToastListener> {
  /// The newest notification timestamp we've already toasted (or the baseline
  /// established on first load). Only notifications strictly newer than this
  /// trigger a toast, so reading/marking an old one never re-pops it.
  DateTime? _lastHandledAt;

  @override
  Widget build(BuildContext context) {
    // Watch the notification stream. When a new unread notification
    // appears, show a floating toast.
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    notificationsAsync.whenData((notifications) {
      if (notifications.isEmpty) return;

      final newest = notifications.first; // stream is newest-first
      if (_lastHandledAt == null) {
        // First load: record the baseline so pre-existing notifications
        // (e.g. all unread ones from before launch) don't all pop up.
        _lastHandledAt = newest.createdAt;
        return;
      }
      if (!newest.createdAt.isAfter(_lastHandledAt!)) return;
      _lastHandledAt = newest.createdAt;

      // Show a floating toast that auto-dismisses.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final theme = Theme.of(context);
        final (iconData, iconColor) = notificationIconFor(newest.type);

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              // Light card — not the default dark charcoal. Reuses the app's
              // white-card toast language (SnackbarUtils._ActionToast): same
              // radius, divider border, soft shadow, tinted icon square and
              // two-line title/body type.
              backgroundColor: Colors.white,
              elevation: 6,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              margin: const EdgeInsets.all(AppConstants.spacingMd),
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingLg,
                vertical: AppConstants.spacingMd,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                side: const BorderSide(color: AppTheme.dividerColor),
              ),
              content: Row(
                children: [
                  // Same per-type icon treatment as the notification list
                  // tile — the notification's own colour on a tinted square.
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    ),
                    child: Icon(iconData, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: AppConstants.spacingMd),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          newest.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          newest.body,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
      });
    });

    return widget.child;
  }
}
