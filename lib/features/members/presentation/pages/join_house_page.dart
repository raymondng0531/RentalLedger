import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/breakpoints.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../features/authentication/presentation/providers/auth_provider.dart';
import '../providers/house_provider.dart';

/// Join House screen — enter invite code to join an existing household.
///
/// Matches the Figma design: invite code input field, join button.
class JoinHousePage extends ConsumerStatefulWidget {
  const JoinHousePage({super.key});

  @override
  ConsumerState<JoinHousePage> createState() => _JoinHousePageState();
}

class _JoinHousePageState extends ConsumerState<JoinHousePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      SnackbarUtils.showError(context, 'Not authenticated.');
      return;
    }

    final errorMessage = await ref.read(joinHouseProvider.notifier).joinHouse(
          _codeController.text,
          user.uid,
        );

    if (!mounted) return;

    if (errorMessage == null) {
      context.go(RouteNames.dashboard);
    } else {
      SnackbarUtils.showError(context, errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(joinHouseProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Join House'),
        backgroundColor: Colors.white,
      ),
      body: ResponsivePage(
        maxWidth: AppContentWidth.form,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.pagePadding),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // ── Logo ──
                  const AppLogo(showTagline: false),
                  const SizedBox(height: 32),

                  // ── Title ──
                  Text(
                    'Enter Invite Code',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask your Treasurer for the invite code.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // ── Invite code input ──
                  TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleJoin(),
                    maxLength: AppConstants.inviteCodeLength,
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Invite Code',
                      hintText: 'ABC12345',
                      counterText: '',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.vpn_key_outlined,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an invite code';
                      }
                      if (value.trim().length < AppConstants.inviteCodeLength) {
                        return 'Code must be ${AppConstants.inviteCodeLength} characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Join button ──
                  FilledButton(
                    onPressed: isLoading ? null : _handleJoin,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Join House'),
                  ),
                  const SizedBox(height: 16),

                  // ── Create instead link ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Flexible lets the text wrap on narrow screens instead of overflowing.
                      const Flexible(child: Text("Don't have a code?")),
                      TextButton(
                        onPressed: () => context.push(RouteNames.createHouse),
                        child: const Text('Create a House'),
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
