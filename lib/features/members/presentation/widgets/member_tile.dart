import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/animated_pressable.dart';
import '../../domain/entities/house_member_entity.dart';

/// A tile displaying a house member with avatar, name, role badge,
/// and optional balance. Wrapped in AnimatedPressable for tactile feedback.
///
/// Matches the Figma design: avatar (circle), name, role, join date.
class MemberTile extends StatelessWidget {
  const MemberTile({
    super.key,
    required this.member,
    this.outstandingBalance,
    this.onTap,
    this.onRemove,
    this.showActions = false,
  });

  final HouseMemberEntity member;
  final double? outstandingBalance;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Guard against empty (non-null) names/emails — indexing ''[0] throws.
    final initialText = (member.displayName != null &&
            member.displayName!.isNotEmpty)
        ? member.displayName!
        : (member.email != null && member.email!.isNotEmpty)
            ? member.email!
            : '?';
    final initial = initialText[0].toUpperCase();

    return AnimatedPressable(
      onTap: onTap,
      scaleAmount: 0.98,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: member.isTreasurer
                ? AppTheme.primaryGreen.withAlpha(30)
                : Colors.grey.withAlpha(30),
            foregroundImage: (member.photoUrl?.isNotEmpty == true)
                ? NetworkImage(member.photoUrl!) as ImageProvider
                : null,
            child: (member.photoUrl?.isNotEmpty == true)
                ? null
                : Text(
                    initial,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: member.isTreasurer
                          ? AppTheme.primaryGreen
                          : Colors.grey,
                    ),
                  ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  member.displayName ??
                      _emailName(member.email) ??
                      'Member',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (member.isTreasurer) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Treasurer',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (member.email != null && member.email!.isNotEmpty)
                  Text(
                    member.email!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  'Joined ${DateFormatUtils.formatDateShort(member.joinedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          trailing: showActions && onRemove != null
              ? IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppTheme.errorRed, size: 20),
                  onPressed: onRemove,
                  tooltip: 'Remove member',
                )
              : null,
        ),
      ),
    );
  }

  /// Derives a display name from an email (e.g. `john@x.com` → `john`).
  String? _emailName(String? email) {
    if (email == null || email.isEmpty) return null;
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return email;
    return email.substring(0, atIndex);
  }
}
