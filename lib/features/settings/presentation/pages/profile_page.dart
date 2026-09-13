import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/vocabulary_labels.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/spring_sheet.dart';
import '../../../../features/authentication/presentation/providers/auth_provider.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../features/members/domain/entities/house_member_entity.dart';
import '../../../../features/members/presentation/providers/house_provider.dart';
import '../providers/settings_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Profile page — view/change photo, view/edit display name, view email.
///
/// Saving writes the change through the auth repository (Firebase Auth +
/// `users/{uid}`) and syncs the active member records, then refreshes the
/// providers the Dashboard/History read so names update immediately.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _picker = ImagePicker();
  late final TextEditingController _nameController;
  File? _pickedPhoto;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(profileProvider)?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _pickedPhoto = File(picked.path));
      }
    } catch (_) {
      if (mounted) {
        SnackbarUtils.showError(context, l10n.profilePhotoFailed);
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return SpringSheet(
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.profileChangePhoto,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text(l10n.actionTakePhoto),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(l10n.actionChooseFromGallery),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      SnackbarUtils.showError(context, l10n.profileDisplayNameEmpty);
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _saving = true);
    try {
      // Upload first, then persist the URL alongside the name.
      String? photoUrl;
      if (_pickedPhoto != null) {
        photoUrl = await ref
            .read(authRepositoryProvider)
            .uploadProfilePhoto(localPath: _pickedPhoto!.path);
      }

      await ref.read(authRepositoryProvider).updateProfile(
            displayName: newName,
            photoUrl: photoUrl,
          );

      // Keep member records in step so History/Members resolve the new name.
      await ref.read(houseRepositoryProvider).updateMemberDisplayInfo(
            userId: user.uid,
            displayName: newName,
            photoUrl: photoUrl,
          );

      if (!mounted) return;

      // Reflect the change everywhere immediately.
      ref.invalidate(currentUserProvider);
      ref.invalidate(profileProvider);
      ref.invalidate(membersStreamProvider);
      ref.invalidate(dashboardDataProvider);

      SnackbarUtils.showSuccess(context, l10n.profileUpdated);
      context.pop();
    } catch (_) {
      if (mounted) {
        SnackbarUtils.showError(context, l10n.profileUpdateFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final house = ref.watch(currentHouseProvider);
    final membersAsync = ref.watch(membersStreamProvider);
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // The signed-in user's member record (role + join date) in this house.
    HouseMemberEntity? currentMember;
    for (final m in membersAsync.value ?? const <HouseMemberEntity>[]) {
      if (m.userId == user?.uid) {
        currentMember = m;
        break;
      }
    }

    final hasPicked = _pickedPhoto != null;
    final photoUrl = hasPicked ? null : profile?.photoUrl;
    final showPhoto =
        (photoUrl != null && photoUrl.isNotEmpty) || hasPicked;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: l10n.actionBack,
        ),
        title: Text(l10n.profileTitle),
      ),
      body: ResponsivePage(
        // maxWidth omitted — defaults to AppContentWidth.detail (800).
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          children: [
            // ── Photo (saving indicator is localized to the avatar) ──
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: context.colors.primary.withAlpha(25),
                    // Web-safe preview: on web `_pickedPhoto.path` is a blob URL
                    // the browser can decode via NetworkImage (no filesystem),
                    // matching the receipt-preview pattern; on native the local
                    // file is decoded directly. FileImage(blob) is unsupported
                    // on web ("Unsupported operation: _Namespace").
                    foregroundImage: hasPicked
                        ? (kIsWeb
                            ? NetworkImage(_pickedPhoto!.path) as ImageProvider
                            : FileImage(_pickedPhoto!) as ImageProvider)
                        : (showPhoto ? NetworkImage(photoUrl!) : null),
                    child: showPhoto
                        ? null
                        : Text(
                            avatarInitial(profile?.displayName),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  // While saving, a compact loading ring sits on the avatar so
                  // a slow photo upload gives localized feedback near the image
                  // — it never dims or washes out the rest of the page.
                  //
                  // The scrim and its ring are deliberately literal. This is a
                  // fixed overlay on top of a photo, not content on a themed
                  // surface: the scrim must darken whatever image is under it
                  // (in either mode) and the ring must stay legible against
                  // that scrim, which only a light ink on a black veil
                  // guarantees. `onAccent`/`surface` tokens would make the ring
                  // vanish into a dark avatar in dark mode.
                  if (_saving)
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(46),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _showPhotoOptions,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(l10n.profileChangePhoto),
              ),
            ),
            const SizedBox(height: 24),

            // ── Fields ──
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: l10n.profileDisplayName,
                        hintText: l10n.profileDisplayNameHint,
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.email_outlined),
                      title: Text(l10n.profileEmail),
                      // The address itself is the user's own data.
                      subtitle: Text(
                        (profile?.email?.isNotEmpty == true)
                            ? profile!.email!
                            : l10n.labelNoEmail,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── House & account ──
            Text(
              l10n.profileHouseAndAccount,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: const Icon(Icons.home_outlined),
                    title: Text(l10n.labelHouse),
                    // The house name is the user's own text.
                    subtitle: Text(house?.houseName ?? l10n.labelNotSet),
                  ),
                  if (currentMember != null) ...[
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: Text(l10n.labelRole),
                      // Stored value → localized label ("Treasurer" / "Member").
                      subtitle: Text(
                        VocabularyLabels.role(currentMember.role, l10n),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: const Icon(Icons.event_available_outlined),
                      title: Text(l10n.profileJoined),
                      subtitle: Text(
                        DateFormatUtils.formatDateShort(
                          currentMember.joinedAt,
                          l10n.localeName,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Save ──
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        // Ink on the FilledButton's `primary` fill.
                        color: context.colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_saving ? l10n.profileSaving : l10n.actionSave),
            ),

            const SizedBox(height: 24),

            // ── Sign out ──
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  Icons.logout_rounded,
                  color: context.colors.error,
                ),
                title: Text(l10n.actionSignOut),
                titleTextStyle: TextStyle(
                  color: context.colors.error,
                  fontWeight: FontWeight.w500,
                ),
                onTap: _confirmSignOut,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Confirms and signs out, returning to the login screen.
  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.actionSignOut),
          content: Text(l10n.actionSignOutConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.actionSignOut),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await ref.read(logoutProvider.notifier).logout();
      if (mounted) {
        context.go(RouteNames.login);
      }
    }
  }
}

