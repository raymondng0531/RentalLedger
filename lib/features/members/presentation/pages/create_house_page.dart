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
import '../../../../features/authentication/presentation/providers/auth_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
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

    final l10n = AppLocalizations.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) {
      SnackbarUtils.showError(context, l10n.houseErrorNotAuthenticated);
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
      SnackbarUtils.showError(
          context, HouseErrorCodes.messageFor(errorMessage, l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(createHouseProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      // This onboarding form is deliberately a clean sheet rather than the grey
      // page tone, so it takes `surface` — which IS the shipped white
      // (#FFFFFFFF) in light mode, and the raised-surface tone in dark mode.
      // Mapping it to `background` instead would have changed light mode to
      // #F5F5F5 and broken the frozen palette.
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        // Pushed from the auth flow — explicit back to return.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: l10n.actionBack,
        ),
        title: Text(l10n.houseCreateTitle),
        // Matches the body it sits on, as it did at #FFFFFF in V1.0.
        backgroundColor: context.colors.surface,
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
                  // ── Logo ──
                  const AppLogo(showTagline: false),
                  const SizedBox(height: 32),

                  // ── Title ──
                  Text(
                    l10n.houseCreateHeading,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.houseCreateSubtitle,
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
                    decoration: InputDecoration(
                      labelText: l10n.labelHouseName,
                      hintText: l10n.houseNameHint,
                      prefixIcon: const Icon(Icons.home_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.houseNameRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── Info card ──
                  Container(
                    padding: const EdgeInsets.all(AppConstants.spacingMd),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: context.colors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.houseCreateTreasurerNotice,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.colors.textSecondary,
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
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              // Ink on the FilledButton's `primary` fill: white
                              // in light mode (unchanged), dark ink on the
                              // lightened dark teal.
                              color: context.colors.onPrimary,
                            ),
                          )
                        : Text(l10n.houseCreateTitle),
                  ),
                  const SizedBox(height: 16),

                  // ── Join instead link ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Flexible lets the text wrap on narrow screens instead of overflowing.
                      Flexible(child: Text(l10n.houseCreateAlreadyHave)),
                      TextButton(
                        onPressed: () => context.push(RouteNames.joinHouse),
                        child: Text(l10n.houseJoinWithCode),
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
