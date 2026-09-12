import 'package:flutter/material.dart';

/// Semantic colour tokens for Rental Ledger, resolved per theme.
///
/// Every colour the UI paints should come from here so a widget never
/// hardcodes a value and never needs to know which mode it is rendering in.
/// Read them through the [AppColorsX] extension:
///
/// ```dart
/// final colors = context.colors;
/// Container(color: colors.surface, ...)
/// ```
///
/// Registered on `ThemeData.extensions` by `AppTheme.lightTheme` and
/// `AppTheme.darkTheme`, which is what makes the tokens follow
/// `ThemeMode.system/light/dark` automatically — switching the mode swaps the
/// registered instance, and every reader repaints.
///
/// **The light palette is frozen.** [AppColors.light] is the shipped V1.0
/// palette, value for value. It is declared as literals rather than aliased to
/// the `AppTheme` constants so the two can be diffed: `app_colors_test.dart`
/// pins every light value to both its literal and its legacy `AppTheme`
/// constant, so neither side can drift while the migration is in progress.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.divider,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.onAccent,
    required this.error,
    required this.success,
    required this.warning,
    required this.statusPending,
    required this.statusApproved,
    required this.statusPaid,
    required this.statusRejected,
    required this.statusDirectPayment,
    required this.statusNeutral,
    required this.categoryFallback,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.placeholderTint,
    required this.glassFill,
    required this.glassBorder,
    required this.glassShadow,
    required this.glassBarFill,
    required this.shadow,
  });

  // ───── Surfaces ─────

  /// Cards, tiles, and other opaque raised content.
  final Color surface;

  /// One step above [surface] — sheets, dialogs, menus, and filled inputs
  /// (Material 3's `surfaceContainerHighest` role).
  final Color surfaceElevated;

  /// A quiet card fill that recedes from [surface] instead of lifting off it.
  ///
  /// Used by rows that should read as a list of subtle blocks rather than as a
  /// stack of raised cards ([ActivityCard], the speed-dial chips' container).
  /// In light mode it is the grey page tone; in dark mode it sits just above
  /// [background], because a fill darker than the page would vanish into it.
  final Color surfaceMuted;

  /// The scaffold behind everything.
  final Color background;

  // ───── Text ─────

  /// Body copy and headings.
  final Color textPrimary;

  /// Supporting copy, labels, captions.
  final Color textSecondary;

  /// Placeholders and de-emphasised iconography. Never the only signal for
  /// something that matters — it sits below AA for small text by design.
  final Color textHint;

  // ───── Lines ─────

  /// Hairline separators between content.
  final Color divider;

  /// Outlines that delineate a control — input borders, unselected chip edges.
  final Color border;

  // ───── Brand and semantics ─────

  /// The brand teal — buttons, links, selected states.
  final Color primary;

  /// Foreground for content **on** [primary].
  ///
  /// Dark mode inks this dark rather than white: the dark palette's primary is
  /// lightened for legibility on dark surfaces, so white-on-primary would fail
  /// contrast. See the Q1b decision.
  final Color onPrimary;

  /// Foreground for content on a *semantic* accent fill — a snackbar's success
  /// green, the muted close-FAB.
  ///
  /// White in light mode, where those accents are deep 500/600 tones. Dark mode
  /// lightens every accent, so the ink flips to near-black: white on `#34D399`
  /// would be about 1.9:1.
  final Color onAccent;

  final Color error;
  final Color success;
  final Color warning;

  // ───── Expense status ─────

  /// Pending review.
  final Color statusPending;

  /// Treasurer-approved, awaiting reimbursement.
  final Color statusApproved;

  /// Reimbursed.
  final Color statusPaid;

  /// Declined by the Treasurer.
  final Color statusRejected;

  /// Paid directly by the payer, bypassing reimbursement.
  final Color statusDirectPayment;

  /// Fallback for an unrecognised status string.
  final Color statusNeutral;

  /// Fallback for a category row that carries no colour of its own.
  ///
  /// Categories normally store their own colour in Firestore; this is only for
  /// the ones that don't. Stored category colours are never rewritten — dark
  /// mode adjusts them at display time, not in the database.
  final Color categoryFallback;

  // ───── Loading placeholders ─────

  /// Resting colour of a skeleton block.
  final Color skeletonBase;

  /// The highlight the shimmer sweeps across [skeletonBase].
  final Color skeletonHighlight;

  /// The flat grey placeholder tint — a second, older placeholder colour than
  /// [skeletonBase], used at low alpha by `SkeletonCard`.
  ///
  /// Kept separate rather than folded into [skeletonBase] because the two are
  /// different greys in the shipped light theme and collapsing them would
  /// change how that card looks today.
  final Color placeholderTint;

  // ───── Glass ─────

  /// Translucent fill of a frosted [GlassCard].
  final Color glassFill;

  /// Hairline edge that catches light around a glass surface.
  final Color glassBorder;

  /// Cast shadow beneath a glass surface.
  final Color glassShadow;

  /// The frosted chrome behind the app bar and bottom navigation.
  ///
  /// Near-opaque rather than heavily translucent: it sits over scrolling
  /// content and must stay legible, so the translucency reads as a tint rather
  /// than as see-through.
  final Color glassBarFill;

  // ───── Elevation ─────

  /// Shadow cast by raised cards.
  final Color shadow;

  // ───── Palettes ─────

  /// The glass strength that [glassFill] is defined at, and the default
  /// `GlassCard.opacity`.
  ///
  /// `GlassCard.opacity` predates the palette: it scaled a raw white fill, and
  /// 0.75 was the value every caller used. The palette now owns the tint, so
  /// the parameter is interpreted as a multiple of *this* reference — which is
  /// what keeps the default call rendering the exact V1.0 fill (`white @ 191`)
  /// while still following the theme.
  static const double glassReferenceStrength = 0.75;

  /// The shipped V1.0 light palette. **Do not change these values.**
  static const AppColors light = AppColors(
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF5F5F5),
    background: Color(0xFFF5F5F5),
    textPrimary: Color(0xFF1D1D1D),
    textSecondary: Color(0xFF6B7280),
    textHint: Color(0xFF9E9E9E),
    divider: Color(0xFFE5E7EB),
    border: Color(0xFFB0B7C3),
    primary: Color(0xFF00897B),
    onPrimary: Color(0xFFFFFFFF),
    onAccent: Color(0xFFFFFFFF),
    error: Color(0xFFDC3545),
    success: Color(0xFF28A745),
    warning: Color(0xFFFFC107),
    statusPending: Color(0xFFFF9800),
    statusApproved: Color(0xFF2196F3),
    statusPaid: Color(0xFF4CAF50),
    statusRejected: Color(0xFFF44336),
    statusDirectPayment: Color(0xFF9C27B0),
    // `Colors.grey`, not the equivalent `Color(0xFF9E9E9E)` literal: the
    // shipped `StatusBadge` fallback *is* this swatch, and `status_badge_test`
    // asserts against it by identity. Value-equal but a different runtime type
    // is still a behaviour change, so the palette keeps the swatch verbatim.
    statusNeutral: Colors.grey,
    categoryFallback: Color(0xFF95A5A6),
    skeletonBase: Color(0xFFEDEFF2),
    skeletonHighlight: Color(0xFFFAFBFC),
    placeholderTint: Color(0xFF9E9E9E),
    glassFill: Color(0xBFFFFFFF),
    glassBorder: Color(0x78FFFFFF),
    glassShadow: Color(0x0A000000),
    glassBarFill: Color(0xF7FFFFFF),
    shadow: Color(0x0D000000),
  );

  /// The dark palette.
  ///
  /// Built as a deep neutral ramp rather than pure black — three surface steps
  /// (`background` → `surface` → `surfaceElevated`) so elevation stays legible
  /// without borders. The ramp is very slightly cool to sit under a teal
  /// accent without clashing.
  ///
  /// Foreground colours are lightened until they clear WCAG AA (4.5:1) against
  /// [surface]; the status and semantic hues move one to two steps up their
  /// Material ramps so they read as themselves on a dark ground instead of
  /// going muddy.
  static const AppColors dark = AppColors(
    surface: Color(0xFF171B1E),
    surfaceElevated: Color(0xFF1F2429),
    surfaceMuted: Color(0xFF1B2125),
    background: Color(0xFF0F1214),
    textPrimary: Color(0xFFF2F4F5),
    textSecondary: Color(0xFFA8B0B8),
    textHint: Color(0xFF828B94),
    divider: Color(0xFF2A3136),
    border: Color(0xFF3A4247),
    // Lighter teal: #00897B is far too dark to read on a dark ground. This is
    // the V1.0 `primaryGreenLight`, so the dark brand colour is derived from
    // the existing palette rather than invented.
    primary: Color(0xFF4DB6AC),
    // Deep teal ink, not black: ~6.8:1 on the primary above.
    onPrimary: Color(0xFF06231F),
    // Near-black ink on the lightened accents (~6.8:1 on the worst of them).
    onAccent: Color(0xFF0F1214),
    error: Color(0xFFF87171),
    success: Color(0xFF34D399),
    warning: Color(0xFFFFD54F),
    statusPending: Color(0xFFFFB74D),
    statusApproved: Color(0xFF64B5F6),
    statusPaid: Color(0xFF81C784),
    statusRejected: Color(0xFFE57373),
    statusDirectPayment: Color(0xFFBA68C8),
    statusNeutral: Color(0xFF9AA4AC),
    categoryFallback: Color(0xFFA8B3B4),
    skeletonBase: Color(0xFF232A2E),
    skeletonHighlight: Color(0xFF2E363B),
    placeholderTint: Color(0xFFB0B8BE),
    // Dark glass lifts with a low-alpha white rather than a white fill — a
    // 75%-white card would blow out the whole surface.
    glassFill: Color(0x1AFFFFFF),
    glassBorder: Color(0x1FFFFFFF),
    // Deeper shadow: a 4% black cast is invisible against a dark ground, so
    // depth in dark mode comes mostly from the surface ramp and this shadow
    // only reinforces it.
    glassShadow: Color(0x33000000),
    glassBarFill: Color(0xF70F1214),
    shadow: Color(0x40000000),
  );

  @override
  AppColors copyWith({
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? background,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? divider,
    Color? border,
    Color? primary,
    Color? onPrimary,
    Color? onAccent,
    Color? error,
    Color? success,
    Color? warning,
    Color? statusPending,
    Color? statusApproved,
    Color? statusPaid,
    Color? statusRejected,
    Color? statusDirectPayment,
    Color? statusNeutral,
    Color? categoryFallback,
    Color? skeletonBase,
    Color? skeletonHighlight,
    Color? placeholderTint,
    Color? glassFill,
    Color? glassBorder,
    Color? glassShadow,
    Color? glassBarFill,
    Color? shadow,
  }) {
    return AppColors(
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      background: background ?? this.background,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      divider: divider ?? this.divider,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      onAccent: onAccent ?? this.onAccent,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      statusPending: statusPending ?? this.statusPending,
      statusApproved: statusApproved ?? this.statusApproved,
      statusPaid: statusPaid ?? this.statusPaid,
      statusRejected: statusRejected ?? this.statusRejected,
      statusDirectPayment: statusDirectPayment ?? this.statusDirectPayment,
      statusNeutral: statusNeutral ?? this.statusNeutral,
      categoryFallback: categoryFallback ?? this.categoryFallback,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      placeholderTint: placeholderTint ?? this.placeholderTint,
      glassFill: glassFill ?? this.glassFill,
      glassBorder: glassBorder ?? this.glassBorder,
      glassShadow: glassShadow ?? this.glassShadow,
      glassBarFill: glassBarFill ?? this.glassBarFill,
      shadow: shadow ?? this.shadow,
    );
  }

  /// Blends toward [other] — used by `MaterialApp` while it animates between
  /// the light and dark themes.
  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    // Return the endpoint palettes themselves rather than a blend at t=0/1.
    // `Color.lerp` always yields a plain `Color`, which would drop the runtime
    // type of a swatch-valued token ([AppColors.light] carries `Colors.grey`)
    // and make the endpoint compare unequal to the palette it came from.
    if (t <= 0.0) return this;
    if (t >= 1.0) return other;

    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;

    return AppColors(
      surface: mix(surface, other.surface),
      surfaceElevated: mix(surfaceElevated, other.surfaceElevated),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      background: mix(background, other.background),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textHint: mix(textHint, other.textHint),
      divider: mix(divider, other.divider),
      border: mix(border, other.border),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      onAccent: mix(onAccent, other.onAccent),
      error: mix(error, other.error),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      statusPending: mix(statusPending, other.statusPending),
      statusApproved: mix(statusApproved, other.statusApproved),
      statusPaid: mix(statusPaid, other.statusPaid),
      statusRejected: mix(statusRejected, other.statusRejected),
      statusDirectPayment: mix(statusDirectPayment, other.statusDirectPayment),
      statusNeutral: mix(statusNeutral, other.statusNeutral),
      categoryFallback: mix(categoryFallback, other.categoryFallback),
      skeletonBase: mix(skeletonBase, other.skeletonBase),
      skeletonHighlight: mix(skeletonHighlight, other.skeletonHighlight),
      placeholderTint: mix(placeholderTint, other.placeholderTint),
      glassFill: mix(glassFill, other.glassFill),
      glassBorder: mix(glassBorder, other.glassBorder),
      glassShadow: mix(glassShadow, other.glassShadow),
      glassBarFill: mix(glassBarFill, other.glassBarFill),
      shadow: mix(shadow, other.shadow),
    );
  }

  // Value equality matters here: `ThemeData` compares its extensions to decide
  // whether dependents must rebuild, and [lerp] produces a fresh instance every
  // animation frame. Without these, a settled theme would keep reporting itself
  // as changed.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppColors &&
        other.surface == surface &&
        other.surfaceElevated == surfaceElevated &&
        other.surfaceMuted == surfaceMuted &&
        other.background == background &&
        other.textPrimary == textPrimary &&
        other.textSecondary == textSecondary &&
        other.textHint == textHint &&
        other.divider == divider &&
        other.border == border &&
        other.primary == primary &&
        other.onPrimary == onPrimary &&
        other.onAccent == onAccent &&
        other.error == error &&
        other.success == success &&
        other.warning == warning &&
        other.statusPending == statusPending &&
        other.statusApproved == statusApproved &&
        other.statusPaid == statusPaid &&
        other.statusRejected == statusRejected &&
        other.statusDirectPayment == statusDirectPayment &&
        other.statusNeutral == statusNeutral &&
        other.categoryFallback == categoryFallback &&
        other.skeletonBase == skeletonBase &&
        other.skeletonHighlight == skeletonHighlight &&
        other.placeholderTint == placeholderTint &&
        other.glassFill == glassFill &&
        other.glassBorder == glassBorder &&
        other.glassShadow == glassShadow &&
        other.glassBarFill == glassBarFill &&
        other.shadow == shadow;
  }

  @override
  int get hashCode => Object.hashAll([
        surface,
        surfaceElevated,
        surfaceMuted,
        background,
        textPrimary,
        textSecondary,
        textHint,
        divider,
        border,
        primary,
        onPrimary,
        onAccent,
        error,
        success,
        warning,
        statusPending,
        statusApproved,
        statusPaid,
        statusRejected,
        statusDirectPayment,
        statusNeutral,
        categoryFallback,
        skeletonBase,
        skeletonHighlight,
        placeholderTint,
        glassFill,
        glassBorder,
        glassShadow,
        glassBarFill,
        shadow,
      ]);
}

/// Reads the active [AppColors] off the ambient theme.
extension AppColorsX on BuildContext {
  /// The semantic colour tokens for the current theme.
  ///
  /// Falls back to [AppColors.light] when no [AppColors] is registered, so a
  /// widget pumped outside a configured `MaterialApp` — most widget tests —
  /// still renders the shipped light palette instead of throwing. Registration
  /// is pinned by `app_colors_test.dart`.
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
