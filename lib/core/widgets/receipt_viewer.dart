import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Full-screen, zoomable receipt viewer on a black background.
///
/// Shared by Add Expense and Expense Details so every receipt is viewed
/// the same way. The caller supplies the resolved [image] (network or
/// local file, web-safe as needed).
///
/// **This widget is intentionally theme-independent, and is the one place in
/// the app where a literal black/white is correct.** All three literals below
/// are the viewing surface itself rather than UI chrome:
///
/// * `Scaffold.backgroundColor: Colors.black` — a photo lightbox. The ground
///   must stay black in BOTH modes: a receipt is usually a bright photo, and
///   against a light ground it would lose its edges, while the letterbox bars
///   around a `BoxFit.contain` fit would glare. Theming it would also make the
///   viewer render *differently* in light vs dark mode, which is precisely what
///   a viewer of a fixed asset should not do.
/// * `AppBar.backgroundColor: Colors.black` — the same ground continued
///   upward. Left on the theme it would be a translucent white bar in light
///   mode sitting on a black body, i.e. a light strip above the photo.
/// * `AppBar.foregroundColor: Colors.white` — required ink on that ground,
///   and it never becomes invisible in either mode because the ground never
///   changes. Neither available token works here: the app-bar theme's
///   `textPrimary` is #1D1D1D in light (near-black on black, ~1.2:1), and
///   `AppColors.dark.onPrimary` is #06231F — also near-black. White on black
///   measures 21:1 in both modes.
///
/// Callers pass error placeholders tinted `Colors.white54` for the same
/// reason; they render on this fixed black ground, not on a themed surface.
class ReceiptViewer extends StatelessWidget {
  const ReceiptViewer({
    super.key,
    required this.image,
    this.title,
  });

  final Widget image;

  /// Caller-supplied title. When null the widget falls back to the localized
  /// "Receipt" — nullable rather than a defaulted literal so that the fallback
  /// follows the active locale.
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // deliberate lightbox ground — see above
      appBar: AppBar(
        backgroundColor: Colors.black, // same ground, continued
        foregroundColor: Colors.white, // required ink on black, both modes
        title: Text(title ?? AppLocalizations.of(context).receiptTitle),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: image,
        ),
      ),
    );
  }
}
