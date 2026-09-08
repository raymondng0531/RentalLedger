import 'package:flutter/widgets.dart';

/// Screen width classes used for responsive layout decisions.
///
/// Mirrors Material 3's window-size classes, with an extra tier for large
/// desktop monitors:
///
/// | [AppBreakpoint] | Width        | Form factor                                  |
/// |-----------------|--------------|----------------------------------------------|
/// | [AppBreakpoint.compact]   | < 600px    | Phones (iPhone, Android)                     |
/// | [AppBreakpoint.medium]    | 600–839px  | Tablets (iPad portrait, Android tablet)      |
/// | [AppBreakpoint.expanded]  | 840–1199px | Desktops, large landscape tablets            |
/// | [AppBreakpoint.extraLarge]| ≥ 1200px   | Large desktop monitors                       |
///
/// The thresholds live in [AppBreakpoints] so pages and widgets never hard-code
/// raw numbers. Classify a width with [AppBreakpoints.of] (from a build
/// context) or [AppBreakpoints.ofSize] (from a raw logical width).
enum AppBreakpoint {
  /// < 600px — phones.
  compact,

  /// 600–839px — tablets.
  medium,

  /// 840–1199px — desktops and large landscape tablets.
  expanded,

  /// ≥ 1200px — large desktop monitors.
  extraLarge;

  /// True for [medium] and wider (viewport ≥ 600px).
  bool get isTabletOrWider =>
      this == AppBreakpoint.medium ||
      this == AppBreakpoint.expanded ||
      this == AppBreakpoint.extraLarge;

  /// True for [expanded] and wider (viewport ≥ 840px).
  bool get isDesktopOrWider =>
      this == AppBreakpoint.expanded || this == AppBreakpoint.extraLarge;

  /// True for [extraLarge] only (viewport ≥ 1200px).
  bool get isLargeDesktop => this == AppBreakpoint.extraLarge;
}

/// Breakpoint thresholds and classification helpers.
///
/// All widths are logical pixels (what `MediaQuery.sizeOf` reports), so they
/// behave identically across devices regardless of pixel density.
class AppBreakpoints {
  AppBreakpoints._();

  /// Compact (phone): widths below this are [AppBreakpoint.compact].
  static const double compactMaxWidth = 600;

  /// Medium (tablet): 600–839px.
  static const double mediumMaxWidth = 840;

  /// Expanded (desktop): 840–1199px.
  static const double expandedMaxWidth = 1200;

  /// Classifies a logical screen width into an [AppBreakpoint].
  static AppBreakpoint ofSize(double width) {
    if (width < compactMaxWidth) return AppBreakpoint.compact;
    if (width < mediumMaxWidth) return AppBreakpoint.medium;
    if (width < expandedMaxWidth) return AppBreakpoint.expanded;
    return AppBreakpoint.extraLarge;
  }

  /// The [AppBreakpoint] for the current build context's viewport width.
  ///
  /// Prefer this over [ofSize] when a build context is available — it reads
  /// the actual window size (logical pixels) and re-lays out on resize, which
  /// matters for responsive web where the user can resize the browser.
  static AppBreakpoint of(BuildContext context) =>
      ofSize(MediaQuery.sizeOf(context).width);
}

/// Recommended content (max) widths by screen category.
///
/// These are the targets the responsive-UI audit identified — forms are narrow,
/// read/list screens medium, dashboard and reports wider. Pages pick a category
/// when they adopt [ResponsivePage] (from `responsive_page.dart`); the value is
/// a *maximum*, so a narrower viewport is never constrained and mobile layouts
/// stay unchanged.
class AppContentWidth {
  AppContentWidth._();

  /// Forms and modal content (auth, add/edit forms): ~440px.
  ///
  /// Wide enough for a full-width text field + button, narrow enough to keep
  /// the eye focused on a single column.
  static const double form = 440;

  /// Detail / list / read screens: 720–840px.
  ///
  /// A comfortable single-column reading width for cards and lists.
  static const double detail = 800;

  /// Dashboard: ~1100–1200px.
  ///
  /// Wide enough for the summary row and multiple sections to breathe on a
  /// desktop without becoming a full-width strip.
  static const double dashboard = 1200;

  /// Reports / analytics: ~1100–1200px.
  ///
  /// Allows the multi-column analytics grid to use its space on desktop.
  static const double reports = 1200;
}
