import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/animated_entrance.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_display.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../authentication/domain/entities/user_entity.dart';
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
  /// True while a house-management write (remove / transfer / leave) is in
  /// flight — shows a blocking progress veil so the action can't be double-tapped.
  bool _isBusy = false;

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
                user,
                isViewerTreasurer,
              ),
            ),
          ),
          // A modal scrim, deliberately not a palette token: it is not
          // "content on a surface" but a veil that darkens whatever is
          // underneath, in either mode. Black at 15% reads as a dim on the
          // light page and as a slightly deeper dim on the dark one, which is
          // the correct behaviour for an overlay — a token tied to `surface`
          // would stop it dimming anything. The spinner above it is the actual
          // signal and is themed by the `ProgressIndicatorTheme`.
          if (_isBusy)
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
    if (_isBusy) return;

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
            // Destructive confirm: the semantic error fill with the palette's
            // "ink on an accent" token. Light mode is unchanged (`error` is the
            // shipped #DC3545, `onAccent` the shipped white); dark mode inks it
            // near-black, because white on the lightened dark red would be
            // about 2.3:1.
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: context.colors.onAccent,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    final error = await ref.read(removeMemberProvider.notifier).remove(member);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (error == null) {
      SnackbarUtils.showSuccess(context, '$label removed from the house.');
    } else {
      SnackbarUtils.showError(context, error);
    }
  }

  /// Confirms with the current Treasurer, then transfers ownership to [target].
  ///
  /// The current Treasurer becomes a regular Member and loses Treasurer-only
  /// controls the moment the transfer commits; the member list and this card
  /// update in realtime from the Firestore streams.
  Future<void> _confirmTransfer(
    HouseEntity house,
    HouseMemberEntity target,
  ) async {
    if (_isBusy) return;

    final viewer = ref.read(currentUserProvider);
    if (viewer == null) return;

    final label = _memberLabel(target);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Transfer Ownership'),
        content: Text(
          'Make $label the new Treasurer of ${house.houseName}?\n\n'
          'You will become a regular Member and will no longer be able to '
          'approve expenses, record deposits or manage the house until '
          'ownership is transferred back to you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    final error = await ref
        .read(transferTreasurerProvider.notifier)
        .transfer(house.houseId, house.treasurerId, target.userId);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (error == null) {
      SnackbarUtils.showSuccess(context, '$label is now the Treasurer.');
    } else {
      SnackbarUtils.showError(context, error);
    }
  }

  /// Bottom sheet listing the other active members as transfer targets.
  Future<HouseMemberEntity?> _pickTransferTarget(
    HouseEntity house,
    List<HouseMemberEntity> others,
  ) {
    return showModalBottomSheet<HouseMemberEntity>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Transfer to…',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            for (final m in others)
              ListTile(
                leading: CircleAvatar(
                  child: Text(_memberLabel(m)[0].toUpperCase()),
                ),
                title: Text(_memberLabel(m)),
                subtitle: const Text('Make this member the Treasurer'),
                onTap: () => Navigator.of(sheetContext).pop(m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Guards the current user's own membership: transfer-or-leave.
  ///
  /// - Treasurer → "Transfer ownership" (disabled until another member exists);
  ///   they can only leave after ownership is transferred, at which point this
  ///   card flips to the member's "Leave house".
  /// - Member → "Leave house" (soft-delete of their own record; account and
  ///   history are kept). The router's house guard then sends them to the
  ///   Create / Join onboarding screen.
  Future<void> _confirmLeave(HouseEntity house) async {
    if (_isBusy) return;

    final viewer = ref.read(currentUserProvider);
    if (viewer == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave House'),
        content: Text(
          'Leave ${house.houseName}?\n\n'
          'You will no longer be able to view this house or submit expenses '
          'until you are invited back. Your account and all past records are '
          'kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            // Destructive confirm: the semantic error fill with the palette's
            // "ink on an accent" token. Light mode is unchanged (`error` is the
            // shipped #DC3545, `onAccent` the shipped white); dark mode inks it
            // near-black, because white on the lightened dark red would be
            // about 2.3:1.
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: context.colors.onAccent,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    final error = await ref
        .read(leaveHouseProvider.notifier)
        .leave(house.houseId, viewer.uid, false);
    if (!mounted) return;
    setState(() => _isBusy = false);

    if (error == null) {
      SnackbarUtils.showSuccess(context, 'You left ${house.houseName}.');
      // The repository cleared the active house; the router's house guard
      // redirects to the Create / Join onboarding screen automatically.
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
    UserEntity? user,
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
                onMakeTreasurer: (isViewerTreasurer &&
                        house != null &&
                        user != null &&
                        m.userId != user.uid)
                    ? () => _confirmTransfer(house, m)
                    : null,
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

          const SizedBox(height: 24),

          // ── The viewer's own membership: transfer (Treasurer) or leave ──
          if (house != null && user != null && user.uid.isNotEmpty)
            _buildMembershipCard(
              context,
              house,
              user,
              members,
              isViewerTreasurer,
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// The current user's own-membership card.
  ///
  /// A Treasurer must transfer ownership before leaving, so they get a
  /// "Transfer ownership" action (disabled until another active member exists)
  /// instead of a leave action. Once they transfer, the realtime role streams
  /// flip them to Member and this card swaps to "Leave house".
  Widget _buildMembershipCard(
    BuildContext context,
    HouseEntity house,
    UserEntity user,
    List<HouseMemberEntity> members,
    bool isTreasurer,
  ) {
    final theme = Theme.of(context);
    final others = members.where((m) => m.userId != user.uid).toList();

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
                'Your membership',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              if (isTreasurer) ...[
                Text(
                  others.isEmpty
                      ? 'You are the Treasurer and currently the only member. '
                          'Another member must join before ownership can be '
                          'transferred.'
                      : 'You are the Treasurer. Transfer ownership to another '
                          'member before you can leave this house.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: others.isEmpty
                      ? null
                      : () => _startTransfer(context, house, others),
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                  label: const Text('Transfer ownership'),
                ),
              ] else ...[
                Text(
                  'You are a Member. You can leave this house at any time; '
                  'your account and past records are kept.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  // Destructive-outline: error ink and edge, from the palette
                  // rather than the legacy constant. Same values in light mode.
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.error,
                    side: BorderSide(color: context.colors.error),
                  ),
                  onPressed: () => _confirmLeave(house),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Leave house'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Picks a transfer target from [others], then runs the transfer.
  Future<void> _startTransfer(
    BuildContext context,
    HouseEntity house,
    List<HouseMemberEntity> others,
  ) async {
    final target = await _pickTransferTarget(house, others);
    if (target == null || !mounted) return;
    await _confirmTransfer(house, target);
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: context.colors.textSecondary,
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
                  // The quiet fill the code sits in: the shipped light grey
                  // (#F5F5F5, unchanged) and its dark-mode counterpart.
                  color: context.colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Text(
                  house.inviteCode,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                    color: context.colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Share this code with housemates to join.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
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
