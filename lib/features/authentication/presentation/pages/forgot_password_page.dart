import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/animated_checkmark.dart';
import '../../../../core/widgets/breakpoints.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';

/// Forgot Password screen — sends a password reset email.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    final failure =
        await ref.read(forgotPasswordProvider.notifier).sendResetEmail(
              _emailController.text.trim(),
            );

    if (!mounted) return;

    if (failure == null) {
      setState(() => _emailSent = true);
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
    final state = ref.watch(forgotPasswordProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      // Full-page auth surface + an opaque app bar, both `surface`: opaque
      // white in light mode exactly as shipped, and the dark card tone in dark
      // mode. The app bar is deliberately *not* `glassBarFill` — that token is
      // translucent (0xF7FFFFFF) and would change the shipped light bar.
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: l10n.actionBack,
        ),
        title: Text(l10n.authResetPasswordTitle),
        backgroundColor: colors.surface,
      ),
      body: ResponsivePage(
        maxWidth: AppContentWidth.form,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.pagePadding),
            child: _emailSent ? _buildSuccessView() : _buildForm(isLoading),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(bool isLoading) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // ── Icon (glass card style) ──
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(16),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withAlpha(40),
                ),
              ),
              child: Icon(
                Icons.lock_reset_rounded,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Title ──
          Text(
            l10n.authResetYourPasswordTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),

          // ── Instructions ──
          Text(
            l10n.authResetInstructions,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 32),

          // ── Email field ──
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleReset(),
            decoration: InputDecoration(
              labelText: l10n.authEmailLabel,
              hintText: l10n.authEmailHint,
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
          const SizedBox(height: 24),

          // ── Send button (primary CTA) ──
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: isLoading ? null : _handleReset,
              icon: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        // Ink for the primary-filled CTA — white in light mode,
                        // dark on the lightened dark teal.
                        color: context.colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(isLoading ? l10n.authSending : l10n.authSendResetLink),
              style: FilledButton.styleFrom(
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Back to login ──
          Center(
            child: TextButton(
              onPressed: () => context.go(RouteNames.login),
              child: Text(l10n.authBackToSignIn),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        const SizedBox(height: 48),

        // ── Animated success checkmark ──
        const Center(
          child: AnimatedCheckmark(),
        ),
        const SizedBox(height: 24),

        Text(
          l10n.authEmailSentTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),

        Text(
          l10n.authEmailSentBody,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        FilledButton(
          onPressed: () => context.go(RouteNames.login),
          child: Text(l10n.authBackToSignIn),
        ),
      ],
    );
  }
}
