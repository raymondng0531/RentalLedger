import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Caps a page's content width and centers it on wide viewports.
///
/// This is the shared wrapper pages adopt to become responsive on Web/desktop
/// without changing their existing layout:
///
/// * On viewports **wider than [maxWidth]** the child is constrained to
///   [maxWidth] and horizontally centered — a form no longer stretches across
///   a 1900px monitor.
/// * On viewports **narrower than [maxWidth]** (every phone, and most
///   tablets) the wrapper is a strict no-op: the child fills the available
///   width exactly as it does today.
///
/// ## Mobile preservation
///
/// The no-op property is deliberate and guaranteed by construction: the child
/// is only centered when there is horizontal headroom
/// (`constraints.maxWidth > maxWidth`), otherwise it is left-aligned, and the
/// [ConstrainedBox] cap is `min(maxWidth, viewport)`. Wrapping a page therefore
/// never narrows, re-centers, or otherwise changes its mobile layout.
///
/// The page keeps its own padding (typically `AppConstants.pagePadding = 16`)
/// inside [child]; [ResponsivePage] only governs width/centering, so wrapping
/// never double-pads. This also means the *content* width on a desktop is
/// `maxWidth − 2 × pagePadding`, exactly as it is on mobile.
///
/// ## Usage
///
/// ```dart
/// body: ResponsivePage(
///   maxWidth: AppContentWidth.form,
///   child: SafeArea(
///     child: SingleChildScrollView(
///       padding: const EdgeInsets.all(AppConstants.pagePadding),
///       child: Form(...),
///     ),
///   ),
/// )
/// ```
///
/// Pick [maxWidth] from [AppContentWidth] (forms ~440, detail/list/read ~800,
/// dashboard/reports ~1200). When the child itself needs to know the current
/// window class, use `AppBreakpoints.of(context)` from `breakpoints.dart`.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    this.maxWidth = AppContentWidth.detail,
    required this.child,
  });

  /// Maximum content width in logical pixels. Content wider than this is only
  /// possible when the viewport itself is wider, so phones are never affected.
  final double maxWidth;

  /// The content to constrain and center.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasHeadroom = constraints.maxWidth > maxWidth;
        return Align(
          // Center only when there is room to spare; left-aligned (the
          // pre-wrapper behaviour) on narrow viewports so mobile is unchanged.
          alignment: hasHeadroom ? Alignment.topCenter : Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
