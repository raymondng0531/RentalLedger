import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Rental Ledger Material Design 3 theme.
///
/// Design tokens extracted from the Figma mockup:
/// - Green primary (#00897B / teal-green from the fintech design)
/// - White cards on light grey (#F5F5F5) background
/// - Rounded corners everywhere (20dp cards, 16dp buttons, 16dp inputs)
/// - High contrast text for readability
class AppTheme {
  AppTheme._();

  // ───── Color tokens ─────

  /// Primary green from the design — a rich teal-green.
  static const Color primaryGreen = Color(0xFF00897B);
  static const Color primaryGreenLight = Color(0xFF4DB6AC);
  static const Color primaryGreenDark = Color(0xFF00695C);

  /// Surface and background.
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  /// Text colors.
  static const Color textPrimary = Color(0xFF1D1D1D);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9E9E9E);

  /// Status badge colors — matching the UI design spec.
  static const Color statusPending = Color(0xFFFF9800); // Orange
  static const Color statusApproved = Color(0xFF2196F3); // Blue
  static const Color statusPaid = Color(0xFF4CAF50); // Green
  static const Color statusRejected = Color(0xFFF44336); // Red
  static const Color statusDirectPayment = Color(0xFF9C27B0); // Purple

  /// Semantic colors.
  static const Color errorRed = Color(0xFFDC3545);
  static const Color successGreen = Color(0xFF28A745);
  static const Color warningOrange = Color(0xFFFFC107);

  /// Divider color.
  static const Color dividerColor = Color(0xFFE5E7EB);

  /// Fallback hex value (not a [Color]) for categories that carry no color.
  /// Used where `Color(c.color ?? ...)` expects an int.
  static const int categoryFallbackHex = 0xFF95A5A6;

  // ───── Theme data ─────

  /// Light theme configuration.
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      onPrimary: Colors.white,
      secondary: primaryGreenLight,
      surface: surfaceWhite,
      error: errorRed,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundLight,

      // ── AppBar (liquid glass — translucent frosted) ──
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Color(0xF7FFFFFF), // ~97% translucent white
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Cards ──
      cardTheme: CardTheme(
        elevation: 1,
        shadowColor: Colors.black.withAlpha(13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        ),
        color: surfaceWhite,
        margin: const EdgeInsets.symmetric(
          horizontal: AppConstants.pagePadding,
          vertical: AppConstants.spacingSm,
        ),
      ),

      // ── Buttons ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingXl,
            vertical: AppConstants.spacingLg,
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(double.infinity, AppConstants.minTouchTarget),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingXl,
            vertical: AppConstants.spacingLg,
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(double.infinity, AppConstants.minTouchTarget),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ── Input fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingLg,
          vertical: AppConstants.spacingLg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          borderSide: const BorderSide(color: Color(0xFFB0B7C3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          borderSide: const BorderSide(color: errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        hintStyle: const TextStyle(color: textHint, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),

      // ── Bottom navigation ──
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xF7FFFFFF), // translucent frosted
        selectedItemColor: primaryGreen,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),

      // ── Floating action button ──
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // ── Bottom sheet ──
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppConstants.radiusBottomSheet),
            topRight: Radius.circular(AppConstants.radiusBottomSheet),
          ),
        ),
      ),

      // ── Divider ──
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      // ── Chip / filter chip ──
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusSm * 2),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingXs,
        ),
        // No Material-3 default outline; each widget sets its own border — a
        // divider-grey hairline when unselected, teal when selected.
        side: BorderSide.none,
        backgroundColor: surfaceWhite,
        surfaceTintColor: Colors.transparent,
        // Selected chips: solid green, no checkmark tick.
        showCheckmark: false,
        selectedColor: primaryGreen,
        checkmarkColor: Colors.white,
        labelStyle: const TextStyle(color: textPrimary),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Snackbar ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
      ),
    );
  }
}
