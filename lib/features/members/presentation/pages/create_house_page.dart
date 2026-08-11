import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../features/authentication/presentation/providers/auth_provider.dart';
import '../providers/house_provider.dart';

/// Create House screen — form to set up a new household.
///
/// Matches the Figma design: logo, house name field, invite code display.
class CreateHousePage extends ConsumerStatefulWidget {
  const CreateHousePage({super.key});

  @override
  ConsumerState<CreateHousePage> createState() => _CreateHousePageState();
}

class _CreateHousePageState extends ConsumerState<CreateHousePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      SnackbarUtils.showError(context, 'Not authenticated.');
      return;
    }

    final errorMessage = await ref.read(createHouseProvider.notifier).createHouse(
          _nameController.text,
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
    final state = ref.watch(createHouseProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // Pushed from the auth flow — explicit back to return.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Create House'),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // ── Logo ──
                const AppLogo(showTagline: false),
                const SizedBox(height: 32),

                // ── Title ──
                Text(
                  'Create Your House',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set up your shared household account.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 32),

                // ── House name ──
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleCreate(),
                  decoration: const InputDecoration(
                    labelText: 'House Name',
                    hintText: 'e.g. Jalan Ampang Homestead',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a house name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ── Info card ──
                Container(
                  padding: const EdgeInsets.all(AppConstants.spacingMd),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundLight,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppTheme.primaryGreen, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You will become the Treasurer of this house.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Create button ──
                FilledButton(
                  onPressed: isLoading ? null : _handleCreate,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create House'),
                ),
                const SizedBox(height: 16),

                // ── Join instead link ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have a house?'),
                    TextButton(
                      onPressed: () => context.push(RouteNames.joinHouse),
                      child: const Text('Join with Code'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
