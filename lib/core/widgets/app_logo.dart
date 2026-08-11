import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// App logo widget — displays the app name with optional tagline.
///
/// Used on the splash screen, login, and register pages.
/// Matches the design: green primary with the app name in bold.
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
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.home_rounded,
            size: iconSize,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // ── App name ──
        Text(
          AppConstants.appName,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: -0.5,
          ),
        ),

        // ── Tagline ──
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text(
            AppConstants.appTagline,
            style: TextStyle(
              fontSize: fontSize * 0.4,
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
