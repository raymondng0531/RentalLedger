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

    final l10n = AppLocalizations.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) {
      SnackbarUtils.showError(context, l10n.houseErrorNotAuthenticated);
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
      SnackbarUtils.showError(
          context, HouseErrorCodes.messageFor(errorMessage, l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(joinHouseProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      // Same clean-sheet treatment as Create House: `surface` is the shipped
      // white (#FFFFFFFF) in light mode, so light is byte-identical, and the
      // raised-surface tone in dark mode. See CreateHousePage for why this is
      // not `background`.
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: l10n.actionBack,
        ),
        title: Text(l10n.houseJoinTitle),
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
                  const SizedBox(height: 24),

                  // ── Logo ──
                  const AppLogo(showTagline: false),
                  const SizedBox(height: 32),

                  // ── Title ──
                  Text(
                    l10n.houseJoinHeading,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.houseJoinSubtitle,
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
                      labelText: l10n.houseInviteCode,
                      // A sample of the code's shape, not a translatable word:
                      // the code itself is user data and keeps its exact
                      // spelling and case. Left as-is on purpose.
                      hintText: 'ABC12345',
                      counterText: '',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.vpn_key_outlined,
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.houseInviteCodeRequired;
                      }
                      if (value.trim().length < AppConstants.inviteCodeLength) {
                        return l10n.houseInviteCodeLength(
                            AppConstants.inviteCodeLength);
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Join button ──
                  FilledButton(
                    onPressed: isLoading ? null : _handleJoin,
                    child: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              // Ink on the FilledButton's `primary` fill.
                              color: context.colors.onPrimary,
                            ),
                          )
                        : Text(l10n.houseJoinTitle),
                  ),
                  const SizedBox(height: 16),

                  // ── Create instead link ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Flexible lets the text wrap on narrow screens instead of overflowing.
                      Flexible(child: Text(l10n.houseJoinNoCode)),
                      TextButton(
                        onPressed: () => context.push(RouteNames.createHouse),
                        child: Text(l10n.houseJoinCreateLink),
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
