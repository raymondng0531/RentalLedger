import 'package:flutter/animation.dart';

/// Application-wide constants.
class AppConstants {
  AppConstants._();

  /// App display name.
  static const String appName = 'Rental Ledger';

  /// App tagline.
  static const String appTagline = 'Your household finances, simplified';

  /// Default currency code.
  static const String defaultCurrencyCode = 'MYR';

  /// Default currency symbol.
  static const String defaultCurrencySymbol = 'RM';

  /// Spacing constants (based on 8px grid).
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  /// Border radius constants.
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusBottomSheet = 24.0;

  /// Page padding.
  static const double pagePadding = 16.0;

  /// Card padding.
  static const double cardPadding = 14.0;

  /// Touch target minimum size (accessibility).
  static const double minTouchTarget = 48.0;

  /// Dashboard query limits.
  static const int recentActivityLimit = 20;
  static const int transactionPageSize = 20;

  /// Password minimum length.
  static const int passwordMinLength = 8;

  /// Invite code length.
  static const int inviteCodeLength = 8;
}

// ──────────────────────────────────────────────
// Animation & Motion Tokens
// ──────────────────────────────────────────────

/// Custom easing curves — stronger than CSS built-ins.
/// Inspired by Emil Kowalski's design engineering philosophy.
class AppEasing {
  AppEasing._();

  /// Strong ease-out for UI interactions (popovers, dropdowns, modals).
  /// Fast start, gentle end — feels responsive.
  static const easeOut = Curves.fastOutSlowIn;

  /// Strong ease-in-out for on-screen movement (transitions, morphing).
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// Deceleration curve for elements entering the screen.
  static const decelerate = Curves.decelerate;

  /// Acceleration curve for elements leaving the screen.
  static const accelerate = Curves.easeIn;

  /// Linear for constant motion (progress bars, marquees).
  static const linear = Curves.linear;

  /// Spring-like bounce for playful interactions (keep bounce 0.1-0.3).
  static const spring = Curves.easeOutBack;
}

/// Animation durations — keep UI under 300ms per Emil's rules.
class AppDurations {
  AppDurations._();

  /// Button press feedback: 100-160ms.
  static const Duration buttonPress = Duration(milliseconds: 120);

  /// Micro-interactions (tooltips, small popovers): 125-200ms.
  static const Duration micro = Duration(milliseconds: 150);

  /// Standard UI transitions (dropdowns, selects): 150-250ms.
  static const Duration standard = Duration(milliseconds: 200);

  /// Page transitions: 250-300ms.
  static const Duration pageTransition = Duration(milliseconds: 280);

  /// Modals, drawers: 200-500ms (use upper end for emphasis).
  static const Duration modal = Duration(milliseconds: 350);

  /// Stagger delay between items: 30-80ms.
  static const Duration stagger = Duration(milliseconds: 50);

  /// Splash screen minimum display time. Kept short — app initialization is
  /// already complete before the splash renders, so this is only a brief
  /// brand moment, not a loading wait.
  static const Duration splash = Duration(milliseconds: 600);

  /// Success checkmark animation.
  static const Duration success = Duration(milliseconds: 400);
}
