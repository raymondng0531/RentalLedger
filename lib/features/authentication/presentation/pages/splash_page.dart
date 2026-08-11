import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_logo.dart';
import '../providers/auth_provider.dart';

/// Splash screen — the first screen users see when launching the app.
///
/// Logo fades in using Emil's ease-out curve for a polished first impression.
/// Checks authentication state and navigates accordingly.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.pageTransition,
    );

    // Fade from 0 to 1 with ease-out (responsive feel per Emil).
    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: AppEasing.easeOut,
    );

    // Subtle scale entrance: start at 0.95, settle at 1.0.
    // Emil: never animate from scale(0) — start from scale(0.95) with opacity.
    _scaleIn = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppEasing.easeOut),
    );

    _controller.forward();
    _checkAuth();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(AppDurations.splash);

    if (!mounted) return;

    final isAuthenticated = ref.read(authRepositoryProvider).currentUser != null;

    if (!mounted) return;

    // Auth redirects should feel instant — no animation (Emil: never animate keyboard-initiated actions).
    context.go(isAuthenticated ? RouteNames.dashboard : RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // ── Animated logo + name + tagline entrance ──
            FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scaleIn,
                child: const AppLogo(size: AppLogoSize.large),
              ),
            ),

            // Calm, minimal — no spinner. Initialization already finished in
            // main() before the splash renders, so the brand mark alone
            // communicates "opening" without implying a wait.
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
