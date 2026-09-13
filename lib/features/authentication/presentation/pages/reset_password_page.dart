import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/animated_checkmark.dart';
import '../../../../core/widgets/breakpoints.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';

/// In-app password reset page (web).
///
/// Opened by Firebase's in-app (`handleCodeInApp`) reset email at
/// `/reset-password?mode=resetPassword&oobCode=…`. The page VALIDATES the real
/// Firebase action code ([ResetPasswordNotifier.verify] →
/// `verifyPasswordResetCode`) before showing the new-password form, and the
/// submit performs the real Firebase reset (`confirmPasswordReset`) — it is
/// never a client-side-only "fake" reset. A missing/invalid/expired code lands
/// on a "request a new link" state instead of a form.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, this.oobCode = ''});

  /// Firebase password-reset action code from the email deep link.
  final String oobCode;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _startedVerify = false;

  @override
  void initState() {
    super.initState();
    _startVerify();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Validates the action code once per page lifetime.
  ///
  /// Runs after the first frame (not synchronously in [initState]) and waits
  /// for the notifier's initial build to settle. An [AutoDisposeAsyncNotifier]
  /// emits its `build()` result (`verifying`) on a microtask, so a state change
  /// made before that emission — e.g. [ResetPasswordNotifier.verify]'s
  /// synchronous "missing code" short-circuit — would be overwritten by the
  /// just-built state and the page would spin on the verifier forever. Waiting
  /// for the initial build (and for the widget's own watch in `build` to hold
  /// the provider open) removes that race.
  void _startVerify() {
    if (_startedVerify) return;
    _startedVerify = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(resetPasswordProvider.future);
      if (!mounted) return;
      ref.read(resetPasswordProvider.notifier).verify(widget.oobCode);
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(resetPasswordProvider.notifier).reset(
          oobCode: widget.oobCode,
          newPassword: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(resetPasswordProvider);
    final data = async.value;
    final status = data?.status;

    final Widget body;
    switch (status) {
      case ResetPasswordStatus.ready:
        body = _buildForm(isSubmitting: false);
      case ResetPasswordStatus.submitting:
        body = _buildForm(isSubmitting: true);
      case ResetPasswordStatus.failed:
        body = _buildForm(
          isSubmitting: false,
          errorMessage: data?.message,
          errorCode: data?.code,
        );
      case ResetPasswordStatus.linkInvalid:
        body = _buildLinkProblem(data?.message, data?.code);
      case ResetPasswordStatus.success:
        body = _buildSuccess();
      case ResetPasswordStatus.verifying:
      case null:
        body = _buildVerifying();
    }

    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(l10n.authResetPasswordTitle),
        backgroundColor: colors.surface,
        // Was a literal `Colors.black`. That is the one light-mode value in
        // this phase that could not be reproduced exactly — and it had to
        // move: on the dark app bar a black title measures about 1.2:1, i.e.
        // invisible. `textPrimary` is the token the app bar theme already uses
        // for exactly this role (#1D1D1D in light, #F2F4F5 in dark), so the
        // title now matches every other app bar in the app instead of being
        // the one screen that inked pure black.
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: ResponsivePage(
        maxWidth: AppContentWidth.form,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.pagePadding),
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _buildVerifying() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 20),
            Text(l10n.authVerifyingLink),
          ],
        ),
      ),
    );
  }

  /// Missing / invalid / expired action code — never show a form for an
  /// unverified link.
  Widget _buildLinkProblem(String? message, String? code) {
    final l10n = AppLocalizations.of(context);
    // A code wins over the fallback message: it is the stable contract the data
    // layer attaches, and it is the only one of the two that can be localized.
    final detail = code != null
        ? localizeAuthError(l10n, code)
        : (message ?? l10n.authResetLinkInvalidBody);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withAlpha(16),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withAlpha(40),
              ),
            ),
            child: Icon(
              Icons.link_off_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          l10n.authResetLinkInvalidTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: () => context.go(RouteNames.forgotPassword),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(l10n.authRequestNewLink),
            style: FilledButton.styleFrom(
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => context.go(RouteNames.login),
            child: Text(l10n.authBackToSignIn),
          ),
        ),
      ],
    );
  }

  Widget _buildForm({
    required bool isSubmitting,
    String? errorMessage,
    String? errorCode,
  }) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
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
          Text(
            l10n.authSetNewPasswordTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.authSetNewPasswordBody(AppConstants.passwordMinLength),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 20),
            _buildErrorBanner(
              errorCode != null
                  ? localizeAuthError(l10n, errorCode)
                  : errorMessage,
            ),
          ],
          const SizedBox(height: 28),

          // ── New password ──
          TextFormField(
            controller: _passwordController,
            obscureText: _obscureNew,
            enabled: !isSubmitting,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.authNewPasswordLabel,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureNew = !_obscureNew),
                tooltip: _obscureNew
                    ? l10n.actionShowPassword
                    : l10n.actionHidePassword,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.authNewPasswordRequired;
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
            controller: _confirmController,
            obscureText: _obscureConfirm,
            enabled: !isSubmitting,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!isSubmitting) _handleSubmit();
            },
            decoration: InputDecoration(
              labelText: l10n.authConfirmNewPasswordLabel,
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                tooltip: _obscureConfirm
                    ? l10n.actionShowPassword
                    : l10n.actionHidePassword,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.authConfirmNewPasswordRequired;
              }
              if (value != _passwordController.text) {
                return l10n.authPasswordsDoNotMatch;
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // ── Submit button (primary CTA) ──
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: isSubmitting ? null : _handleSubmit,
              icon: isSubmitting
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
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(isSubmitting
                  ? l10n.authResetting
                  : l10n.authResetPasswordTitle),
              style: FilledButton.styleFrom(
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => context.go(RouteNames.login),
              child: Text(l10n.authBackToSignIn),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        const SizedBox(height: 48),
        const Center(child: AnimatedCheckmark()),
        const SizedBox(height: 24),
        Text(
          l10n.authPasswordUpdatedTitle,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.authPasswordUpdatedBody,
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
