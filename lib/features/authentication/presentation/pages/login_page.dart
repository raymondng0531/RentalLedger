import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/breakpoints.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/auth_error_codes.dart';
import '../providers/auth_provider.dart';

/// Login screen — email and password authentication.
///
/// Matches the Figma design: logo at top, email/password fields,
/// sign-in button, forgot password link, and register CTA.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final failure = await ref.read(loginProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;

    if (failure == null) {
      // Success — GoRouter's auth guard will redirect to dashboard.
      context.go(RouteNames.dashboard);
    } else {
      SnackbarUtils.showError(
        context,
        localizeAuthError(AppLocalizations.of(context), failure.code),
      );
    }
  }

  /// Handles Google / Apple sign-in.
  ///
  /// A cancelled sign-in is recognised by [AuthErrorCodes.cancelled], never by
  /// the message text. The user dismissed the sheet themselves, so there is
  /// nothing to report and no snackbar is shown.
  Future<void> _handleSocial(String provider) async {
    final failure =
        await ref.read(socialLoginProvider.notifier).loginWith(provider);

    if (!mounted) return;

    if (failure == null) {
      context.go(RouteNames.dashboard);
    } else if (failure.code != AuthErrorCodes.cancelled) {
      SnackbarUtils.showError(
        context,
        localizeAuthError(AppLocalizations.of(context), failure.code),
      );
    }
  }

  /// Apple Sign-In only works on iOS/macOS without extra web setup.
  bool get _supportsAppleSignIn =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final loginState = ref.watch(loginProvider);
    final socialState = ref.watch(socialLoginProvider);
    final isLoading = loginState.isLoading;
    final socialLoading = socialState.isLoading;

    return Scaffold(
      // Opaque white in light mode, the dark card tone in dark mode. An auth
      // screen is a full-page surface, so it takes `surface` rather than the
      // scaffold's default `background` — that is what V1.0 shipped.
      backgroundColor: colors.surface,
      body: ResponsivePage(
        maxWidth: AppContentWidth.form,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.pagePadding),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // ── Logo ──
                  const AppLogo(),
                  const SizedBox(height: 48),

                  // ── Email field ──
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.authEmailLabel,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.authEmailRequired;
                      }
                      if (!value.trim().contains('@')) {
                        return l10n.authEmailInvalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Password field ──
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    decoration: InputDecoration(
                      labelText: l10n.authPasswordLabel,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.authPasswordRequired;
                      }
                      if (value.length < AppConstants.passwordMinLength) {
                        return l10n.authPasswordMinLength(
                            AppConstants.passwordMinLength);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // ── Forgot Password ──
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push(RouteNames.forgotPassword),
                      child: Text(l10n.authForgotPassword),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Login button ──
                  FilledButton(
                    onPressed: isLoading ? null : _handleLogin,
                    child: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              // The FilledButton's fill is `primary`, whose
                              // foreground is `onPrimary` — white in light mode
                              // (unchanged), dark ink on the lightened dark
                              // teal.
                              color: colors.onPrimary,
                            ),
                          )
                        : Text(l10n.authSignIn),
                  ),
                  const SizedBox(height: 24),

                  // ── Divider "or continue with" ──
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          l10n.authOrContinueWith,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Google button ──
                  OutlinedButton.icon(
                    onPressed: socialLoading ? null : () => _handleSocial('google'),
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                    label: Text(l10n.authContinueWithGoogle),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.divider),
                    ),
                  ),
                  // ── Apple button (only on iOS/macOS where it works) ──
                  if (_supportsAppleSignIn) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: socialLoading ? null : () => _handleSocial('apple'),
                      icon: const Icon(Icons.apple_rounded, size: 20),
                      label: Text(l10n.authContinueWithApple),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.divider),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Register link ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Flexible lets the text wrap on narrow screens instead of overflowing.
                      Flexible(child: Text(l10n.authNoAccountPrompt)),
                      TextButton(
                        onPressed: () => context.push(RouteNames.register),
                        child: Text(l10n.authSignUp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
