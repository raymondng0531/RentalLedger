import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/animated_entrance.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../domain/entities/house_entity.dart';
import '../../domain/entities/house_member_entity.dart';
import '../providers/house_provider.dart';
import '../widgets/member_tile.dart';

/// Member List screen — displays all house members with their roles.
///
/// Shows Treasurer badge, join date, and allows management actions.
class MemberListPage extends ConsumerWidget {
  const MemberListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final house = ref.watch(currentHouseProvider);
    final membersAsync = ref.watch(membersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: Text(house?.houseName ?? 'Members'),
      ),
      body: membersAsync.when(
        loading: () => const Shimmer(child: SkeletonListBody(itemCount: 5)),
        error: (error, _) => ErrorDisplay(
          message: error is Failure
              ? error.message
              : 'Could not load members.',
          onRetry: () => ref.invalidate(membersStreamProvider),
        ),
        data: (members) => _buildMemberList(context, ref, members, house),
      ),
    );
  }

  Widget _buildMemberList(
    BuildContext context,
    WidgetRef ref,
    List<HouseMemberEntity> members,
    HouseEntity? house,
  ) {
    if (members.isEmpty) {
      return const EmptyState(
        title: 'No members yet',
        description: 'Share your invite code to add housemates.',
        icon: Icons.people_outlined,
      );
    }

    final treasurer = members.where((m) => m.isTreasurer).toList();
    final regulars = members.where((m) => !m.isTreasurer).toList();

    return RefreshIndicator(
      onRefresh: () async {
        // The list watches the stream provider, so refresh that one.
        ref.invalidate(membersStreamProvider);
      },
      child: ListView(
        padding: const EdgeInsets.only(top: AppConstants.spacingSm),
        children: [
          // ── Section: Treasurer ──
          if (treasurer.isNotEmpty) ...[
            _buildSectionHeader(context, 'Treasurer'),
            ...staggeredEntrance(
              context,
              treasurer,
              (context, m) => MemberTile(member: m),
              keyOf: (m) => m.userId,
            ),
            const SizedBox(height: 8),
          ],

          // ── Section: Members ──
          if (regulars.isNotEmpty) ...[
            _buildSectionHeader(context, 'Members'),
            ...staggeredEntrance(
              context,
              regulars,
              (context, m) => MemberTile(member: m),
              keyOf: (m) => m.userId,
            ),
          ],

          const SizedBox(height: 24),

          // ── Invite code section ──
          if (house != null) _buildInviteCodeSection(context, ref, house),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildInviteCodeSection(
      BuildContext context, WidgetRef ref, HouseEntity house) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite Code',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Text(
                  house.inviteCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Share this code with housemates to join.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // ── Copy + Share actions ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: house.inviteCode),
                        );
                        if (context.mounted) {
                          SnackbarUtils.showSuccess(
                              context, 'Invite code copied!');
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    // Builder gives the Share button its own BuildContext so
                    // we can resolve the button's global Rect to anchor the
                    // share sheet (required on iPadOS and web).
                    child: Builder(
                      builder: (buttonContext) => FilledButton.icon(
                        onPressed: () =>
                            _shareInviteCode(buttonContext, house.inviteCode),
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('Share'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shares the invite code via the platform share sheet (iPhone-style).
  ///
  /// [context] is the Share button's own build context: its render box is used
  /// to compute the button's global [Rect] as [Share.share]'s
  /// `sharePositionOrigin`, which anchors the share sheet to the button. That
  /// origin is required on iPadOS (the share sheet is a popover and throws
  /// without it) and on Flutter Web; Android and iPhone ignore it.
  Future<void> _shareInviteCode(BuildContext context, String code) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    await Share.share(
      'Join my house on Rental Ledger!\n\nInvite Code: $code',
      subject: 'Rental Ledger Invite',
      sharePositionOrigin: origin,
    );
  }
}
