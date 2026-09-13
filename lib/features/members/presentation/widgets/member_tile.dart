import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/vocabulary_labels.dart';
import '../../../../core/widgets/animated_pressable.dart';
import '../../domain/entities/house_member_entity.dart';
import '../../../../l10n/generated/app_localizations.dart';

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
    this.onMakeTreasurer,
    this.showActions = false,
  });

  final HouseMemberEntity member;
  final double? outstandingBalance;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  /// Invoked when the house Treasurer chooses to transfer ownership to this
  /// (regular) member. Only offered on regular-member tiles.
  final VoidCallback? onMakeTreasurer;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.colors;
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
            // A non-Treasurer's avatar is the "no particular role" case, so it
            // takes `statusNeutral` — the palette's existing neutral, which is
            // the very `Colors.grey` swatch V1.0 used here (same value, same
            // material swatch) and a desaturated slate in dark mode.
            backgroundColor: member.isTreasurer
                ? colors.primary.withAlpha(30)
                : colors.statusNeutral.withAlpha(30),
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
                          ? colors.primary
                          : colors.statusNeutral,
                    ),
                  ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  // A name is the member's own data and is never translated;
                  // only the last-resort placeholder is.
                  member.displayName ??
                      _emailName(member.email) ??
                      l10n.labelMember,
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
                    color: colors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    // The stored role is the exact string `Treasurer`; only
                    // its on-screen label is localized, via the shared mapper.
                    VocabularyLabels.role(member.role, l10n),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
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
                      color: colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  l10n.houseJoinedOn(DateFormatUtils.formatDateShort(
                      member.joinedAt, l10n.localeName)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Treasurer management actions on regular-member tiles. The tile is
          // never given actions on the Treasurer's own row (ownership must be
          // transferred, not removed).
          trailing: showActions &&
                  (!member.isTreasurer) &&
                  (onMakeTreasurer != null || onRemove != null)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onMakeTreasurer != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.admin_panel_settings_outlined,
                            color: colors.primary, size: 20),
                        onPressed: onMakeTreasurer,
                        tooltip: l10n.houseMakeTreasurer,
                      ),
                    if (onRemove != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.remove_circle_outline,
                            color: colors.error, size: 20),
                        onPressed: onRemove,
                        tooltip: l10n.houseRemoveMemberTooltip,
                      ),
                  ],
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
