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
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../domain/entities/house_entity.dart';
import '../../domain/entities/house_member_entity.dart';
import '../providers/house_provider.dart';
import '../widgets/member_tile.dart';

/// Member List screen — displays all house members with their roles.
///
/// Shows Treasurer badge, join date, and allows management actions.
/// The Treasurer can remove a former member (soft delete) from the row's
/// trailing Remove action; the member's account and all historical records
/// are untouched.
class MemberListPage extends ConsumerStatefulWidget {
  const MemberListPage({super.key});

  @override
  ConsumerState<MemberListPage> createState() => _MemberListPageState();
}

class _MemberListPageState extends ConsumerState<MemberListPage> {
  bool _isRemoving = false;

  @override
  Widget build(BuildContext context) {
    final house = ref.watch(currentHouseProvider);
    final membersAsync = ref.watch(membersStreamProvider);
    final user = ref.watch(currentUserProvider);
    final isViewerTreasurer = house != null &&
        user != null &&
        user.uid.isNotEmpty &&
        house.treasurerId == user.uid;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: Text(house?.houseName ?? 'Members'),
      ),
      body: Stack(
        children: [
          ResponsivePage(
            // maxWidth omitted — defaults to AppContentWidth.detail (800).
            child: membersAsync.when(
              loading: () => const Shimmer(child: SkeletonListBody(itemCount: 5)),
              error: (error, _) => ErrorDisplay(
                message: error is Failure
                    ? error.message
                    : 'Could not load members.',
                onRetry: () => ref.invalidate(membersStreamProvider),
              ),
              data: (members) => _buildMemberList(
                context,
                ref,
                members,
                house,
                isViewerTreasurer,
              ),
            ),
          ),
          if (_isRemoving)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  /// Confirms with the Treasurer, then soft-removes [member] from [house].
  Future<void> _confirmRemove(
    HouseEntity house,
    HouseMemberEntity member,
  ) async {
    if (_isRemoving) return;

    final label = _memberLabel(member);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Remove $label from ${house.houseName}?\n\n'
          'They will no longer be part of this house or be able to access '
          'its data. Their account and all past expense and transaction '
          'history will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRemoving = true);
    final error = await ref.read(removeMemberProvider.notifier).remove(member);
    if (!mounted) return;
    setState(() => _isRemoving = false);

    if (error == null) {
      SnackbarUtils.showSuccess(context, '$label removed from the house.');
    } else {
      SnackbarUtils.showError(context, error);
    }
  }

  String _memberLabel(HouseMemberEntity member) {
    if (member.displayName != null && member.displayName!.isNotEmpty) {
      return member.displayName!;
    }
    if (member.email != null && member.email!.isNotEmpty) {
      return member.email!;
    }
    return 'This member';
  }

  Widget _buildMemberList(
    BuildContext context,
    WidgetRef ref,
    List<HouseMemberEntity> members,
    HouseEntity? house,
    bool isViewerTreasurer,
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
          // The Treasurer tile never offers a remove action — the house
          // Treasurer can only leave after transferring ownership.
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
          // Only the house Treasurer sees the trailing Remove action, and only
          // on regular members. The removal is a soft delete of the member's
          // house_members record — the membersStreamProvider the page watches
          // filters on isActive == true, so the list refreshes on its own.
          if (regulars.isNotEmpty) ...[
            _buildSectionHeader(context, 'Members'),
            ...staggeredEntrance(
              context,
              regulars,
              (context, m) => MemberTile(
                member: m,
                showActions: isViewerTreasurer,
                onRemove: (isViewerTreasurer && house != null)
                    ? () => _confirmRemove(house, m)
                    : null,
              ),
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
