import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../l10n/generated/app_localizations.dart';

/// App logo widget — displays the app name with optional tagline.
///
/// Used on the splash screen, login, and register pages.
/// Matches the design: green primary with the app name in bold.
///
/// The mark is a filled tile in the brand teal with the home glyph knocked out
/// of it, so the glyph is `onPrimary` rather than a literal white — see the
/// note in [build].
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = AppLogoSize.medium,
    this.showTagline = true,
  });

  final AppLogoSize size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final iconSize = switch (size) {
      AppLogoSize.small => 40.0,
      AppLogoSize.medium => 56.0,
      AppLogoSize.large => 80.0,
    };

    final fontSize = switch (size) {
      AppLogoSize.small => 20.0,
      AppLogoSize.medium => 28.0,
      AppLogoSize.large => 36.0,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Icon ──
        Container(
          width: iconSize * 1.8,
          height: iconSize * 1.8,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.home_rounded,
            size: iconSize,
            // `onPrimary`, not a literal white. Dark mode lightens the brand
            // teal to #4DB6AC, where a white glyph measures about 1.9:1 —
            // effectively invisible. Light mode resolves to the same
            // #FFFFFF the mark has always shipped, so nothing moves there.
            color: colors.onPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // ── App name ──
        Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: colors.primary,
            letterSpacing: -0.5,
          ),
        ),

        // ── Tagline ──
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            // `AppConstants.appName` above stays a constant: the product name
            // is a proper noun and is never translated. The tagline is real
            // copy, so it comes from the ARB files.
            AppLocalizations.of(context).appTagline,
            style: TextStyle(
              fontSize: fontSize * 0.4,
              // Deliberately left on the colour scheme: `onSurfaceVariant` is
              // a *computed* role, so both `ColorScheme.fromSeed` calls already
              // derive a legible value for their brightness. Swapping it for a
              // palette token would re-colour light mode for no dark-mode gain.
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

enum AppLogoSize { small, medium, large }
