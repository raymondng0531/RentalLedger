import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../constants/app_constants.dart';

/// App-wide snackbar helpers for clear, consistent feedback.
///
/// Each type uses a distinct color + icon for instant recognition:
/// - Success → green ✓
/// - Error → red ✕
/// - Warning → orange ⚠
/// - Info → blue ℹ
class SnackbarUtils {
  SnackbarUtils._();

  /// Green success snackbar.
  static void showSuccess(BuildContext context, String message) {
    _show(context, message,
        color: AppTheme.successGreen, icon: Icons.check_circle_rounded);
  }

  /// Red error snackbar.
  static void showError(BuildContext context, String message) {
    _show(context, message,
        color: AppTheme.errorRed, icon: Icons.error_rounded);
  }

  /// Orange warning snackbar.
  static void showWarning(BuildContext context, String message) {
    _show(context, message,
        color: AppTheme.warningOrange, icon: Icons.warning_amber_rounded);
  }

  /// Blue info snackbar.
  static void showInfo(BuildContext context, String message) {
    _show(context, message,
        color: AppTheme.statusApproved, icon: Icons.info_rounded);
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color color,
    required IconData icon,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ───── Compact action toast ─────

  static OverlayEntry? _activeToastEntry;

  /// Shows a compact, floating toast anchored just above the bottom action
  /// area (the docked "+" FAB). Unlike the full-width SnackBars above it:
  ///
  /// - is compact + centered, so it never covers charts or page content;
  /// - floats in the root overlay, so it stays above the bottom bar, the "+"
  ///   FAB and the speed-dial menu (never hidden behind them);
  /// - auto-dismisses after ~2s and never resizes or blocks the page
  ///   ([IgnorePointer] lets taps pass through).
  static void showActionToast(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Replace any visible action toast (mirrors `hideCurrentSnackBar`).
    _activeToastEntry?.remove();
    _activeToastEntry = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ActionToast(
        message: message,
        onDone: () {
          if (_activeToastEntry == entry) _activeToastEntry = null;
          entry.remove();
        },
      ),
    );
    _activeToastEntry = entry;
    overlay.insert(entry);
  }
}

/// The overlay-hosted toast: animates in, holds, fades out, then removes
/// itself. Hosted in a [Positioned] so it never affects page layout.
class _ActionToast extends StatefulWidget {
  const _ActionToast({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_ActionToast> createState() => _ActionToastState();
}

class _ActionToastState extends State<_ActionToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.standard,
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        widget.onDone();
      }
    });
    _autoDismissTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // Clearance above the docked "+" FAB: bottom bar (56) + FAB overhang (28)
    // + a visual gap (16), plus the OS bottom inset.
    const clearance = 56.0 + 28.0 + AppConstants.spacingLg;

    return Positioned(
      left: 0,
      right: 0,
      bottom: safeBottom + clearance,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: _controller,
              curve: AppEasing.easeOut,
            ),
            child: _toastCard(),
          ),
        ),
      ),
    );
  }

  Widget _toastCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withAlpha(22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_rounded,
              color: AppTheme.primaryGreen,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              widget.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
