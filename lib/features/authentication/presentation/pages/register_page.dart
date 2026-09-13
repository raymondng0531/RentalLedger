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
import '../providers/auth_provider.dart';

/// Registration screen — create a new account.
///
/// Matches the Figma design: logo at top, name/email/password fields,
/// sign-up button, and login CTA.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final failure = await ref.read(registerProvider.notifier).register(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final registerState = ref.watch(registerProvider);
    final isLoading = registerState.isLoading;

    return Scaffold(
      // Same full-page surface treatment as Login — see the note there.
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
                  const SizedBox(height: 32),

                  // ── Logo ──
                  const AppLogo(showTagline: false),
                  const SizedBox(height: 32),

                  // ── Title ──
                  Text(
                    l10n.authCreateAccount,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.authRegisterSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // ── Full name ──
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.authFullNameLabel,
                      prefixIcon: const Icon(Icons.person_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.authNameRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Email ──
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

                  // ── Password ──
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
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
                        return l10n.authCreatePasswordRequired;
                      }
                      if (value.length < AppConstants.passwordMinLength) {
                        return l10n.authPasswordMinLength(
                            AppConstants.passwordMinLength);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Confirm password ──
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleRegister(),
                    decoration: InputDecoration(
                      labelText: l10n.authConfirmPasswordLabel,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.authConfirmPasswordRequired;
                      }
                      if (value != _passwordController.text) {
                        return l10n.authPasswordsDoNotMatch;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // ── Register button ──
                  FilledButton(
                    onPressed: isLoading ? null : _handleRegister,
                    child: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : Text(l10n.authCreateAccount),
                  ),
                  const SizedBox(height: 24),

                  // ── Login link ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Flexible lets the text wrap on narrow screens instead of overflowing.
                      Flexible(child: Text(l10n.authHaveAccountPrompt)),
                      TextButton(
                        onPressed: () => context.go(RouteNames.login),
                        child: Text(l10n.authSignIn),
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
