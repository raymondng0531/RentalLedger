import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/animated_checkmark.dart';
import '../../../../core/widgets/breakpoints.dart';
import '../../../../core/widgets/responsive_page.dart';
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

    final errorMessage =
        await ref.read(forgotPasswordProvider.notifier).sendResetEmail(
              _emailController.text.trim(),
            );

    if (!mounted) return;

    if (errorMessage == null) {
      setState(() => _emailSent = true);
    } else {
      SnackbarUtils.showError(context, errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Reset Password'),
        backgroundColor: Colors.white,
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
            'Reset your password',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),

          // ── Instructions ──
          Text(
            'Enter your email and we\'ll send you a secure link to reset your password.',
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
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!value.trim().contains('@')) {
                return 'Please enter a valid email';
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
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(isLoading ? 'Sending...' : 'Send Reset Link'),
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
              child: const Text('Back to Sign In'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        const SizedBox(height: 48),

        // ── Animated success checkmark ──
        const Center(
          child: AnimatedCheckmark(),
        ),
        const SizedBox(height: 24),

        Text(
          'Email Sent!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),

        Text(
          'Check your inbox for the password reset link. '
          'It may take a few minutes to arrive.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        FilledButton(
          onPressed: () => context.go(RouteNames.login),
          child: const Text('Back to Sign In'),
        ),
      ],
    );
  }
}
