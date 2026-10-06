import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/spring_sheet.dart';
import '../../../../features/authentication/presentation/providers/auth_provider.dart';
import '../../../../features/members/presentation/providers/house_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../providers/settings_provider.dart';

/// Settings screen — all app preferences in one place.
///
/// Sections: House, Account, Appearance, Notifications, Language,
/// Currency, Help, About.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final house = ref.watch(currentHouseProvider);
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: l10n.actionBack,
        ),
        title: Text(l10n.navSettings),
      ),
      body: ResponsivePage(
        // maxWidth omitted — defaults to AppContentWidth.detail (800).
        child: ListView(
          children: [
            // ── Profile header ──
            Container(
              padding: const EdgeInsets.all(20),
              // The profile header sits on the card surface, not the page tone
              // — the shipped white (#FFFFFFFF) in light mode, unchanged.
              color: context.colors.surface,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: context.colors.primary.withAlpha(30),
                    foregroundImage: (profile?.photoUrl?.isNotEmpty == true)
                        ? NetworkImage(profile!.photoUrl!) as ImageProvider
                        : null,
                    child: (profile?.photoUrl?.isNotEmpty == true)
                        ? null
                        : Text(
                            avatarInitial(profile?.displayName),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: context.colors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName ?? l10n.settingsUser,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          profile?.email ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push(RouteNames.profile),
                    tooltip: l10n.settingsEditProfile,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── House Section ──
            _SectionHeader(title: l10n.labelHouse),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: Text(l10n.labelHouseName),
                    subtitle: Text(house?.houseName ?? l10n.labelNotSet),
                  ),
                  if (house != null) ...[
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.vpn_key_outlined),
                      title: Text(l10n.settingsInviteCode),
                      subtitle: Text(house.inviteCode),
                      trailing: const Icon(Icons.copy_rounded, size: 18),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: house.inviteCode));
                        SnackbarUtils.showSuccess(
                            context, l10n.settingsInviteCodeCopied);
                      },
                    ),
                  ],
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.people_outlined),
                    title: Text(l10n.labelMembers),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RouteNames.members),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Account Section ──
            _SectionHeader(title: l10n.settingsAccount),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outlined),
                    title: Text(l10n.settingsEditProfile),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RouteNames.profile),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Appearance Section ──
            // The V1.0 row was a "Dark Mode — Coming soon" switch wired to a
            // stub. It is replaced by the real selector because a two-state
            // switch cannot express the three modes the theme architecture
            // already persists (system / light / dark) — and the subtitle now
            // reports the *stored* choice, so the control reflects what
            // `appSettingsProvider` actually holds.
            _SectionHeader(title: l10n.settingsAppearance),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: Text(l10n.settingsTheme),
                subtitle: Text(themeModeLabel(settings.themeMode, l10n)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemePicker(context, ref, settings),
              ),
            ),

            const SizedBox(height: 8),

            // ── Notifications Section ──
            _SectionHeader(title: l10n.navNotifications),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: Text(l10n.settingsPushNotifications),
                    subtitle: Text(l10n.settingsNotificationsSubtitle),
                    value: settings.notificationsEnabled,
                    onChanged: (v) => ref
                        .read(appSettingsProvider.notifier)
                        .setNotificationsEnabled(v),
                  ),
                  // Web only: browsers (Safari on iPhone in particular) grant
                  // notification permission only from a tap.
                  if (kIsWeb) const _PushDeviceTile(),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Preferences Section ──
            _SectionHeader(title: l10n.settingsPreferences),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language_outlined),
                    title: Text(l10n.languageSectionTitle),
                    // Keyed off the *selected* language, not the ambient one:
                    // a language is listed in its own language, so someone who
                    // switched by accident can still find their way back.
                    subtitle: Text(
                      settings.language == 'ms'
                          ? l10n.languageMalay
                          : l10n.languageEnglish,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showLanguagePicker(context, ref, settings),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.attach_money_outlined),
                    title: Text(l10n.settingsCurrency),
                    // The stored currency code is shown exactly as stored.
                    subtitle: Text(settings.currency),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showCurrencyPicker(context, ref, settings),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Help Section ──
            _SectionHeader(title: l10n.labelSupport),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text(l10n.settingsHelpCenter),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showHelpDialog(context),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(l10n.labelAbout),
                    subtitle: Text(l10n.settingsVersion('1.0.0')),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        // The product name is not translated.
                        applicationName: 'Rental Ledger',
                        applicationVersion: '1.0.0',
                        applicationLegalese: l10n.settingsAboutLegalese,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Sign Out (at the very end) ──
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Icon(Icons.logout_rounded, color: context.colors.error),
                title: Text(l10n.actionSignOut),
                titleTextStyle: TextStyle(
                  color: context.colors.error,
                  fontWeight: FontWeight.w500,
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) {
                      final dialogL10n = AppLocalizations.of(ctx);
                      return AlertDialog(
                        title: Text(dialogL10n.actionSignOut),
                        content: Text(dialogL10n.actionSignOutConfirm),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(dialogL10n.actionCancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(dialogL10n.actionSignOut),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirmed == true) {
                    await ref.read(logoutProvider.notifier).logout();
                    if (context.mounted) {
                      context.go(RouteNames.login);
                    }
                  }
                },
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Appearance picker — the three modes the theme architecture supports.
  ///
  /// Writes through [AppSettingsNotifier.setThemeMode], i.e. the same
  /// `PreferencesService` slot the app hydrates from before `runApp`, so the
  /// choice survives a reload and there is no second preference mechanism.
  /// Nothing here touches Firestore — appearance stays device-scoped.
  void _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    showModalBottomSheet(
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
                  child: Text(l10n.settingsAppearance,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                for (final mode in ThemeMode.values)
                  ListTile(
                    title: Text(themeModeLabel(mode, l10n)),
                    subtitle: mode == ThemeMode.system
                        ? Text(l10n.settingsThemeSystemHint)
                        : null,
                    trailing: settings.themeMode == mode
                        ? Icon(Icons.check, color: context.colors.primary)
                        : null,
                    onTap: () {
                      ref.read(appSettingsProvider.notifier).setThemeMode(mode);
                      Navigator.pop(ctx);
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

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.settingsHelpCenter),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                // The product name is never translated.
                'Rental Ledger',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(l10n.settingsHelpIntro),
              const SizedBox(height: 16),
              _HelpItem(
                icon: Icons.receipt_long_outlined,
                title: l10n.settingsHelpSubmitExpenses,
                description: l10n.settingsHelpSubmitExpensesDesc,
              ),
              _HelpItem(
                icon: Icons.check_circle_outline,
                title: l10n.settingsHelpTreasurerApproval,
                description: l10n.settingsHelpTreasurerApprovalDesc,
              ),
              _HelpItem(
                icon: Icons.wallet_outlined,
                title: l10n.settingsHelpReimbursements,
                description: l10n.settingsHelpReimbursementsDesc,
              ),
              _HelpItem(
                icon: Icons.vpn_key_outlined,
                title: l10n.settingsHelpInviteHousemates,
                description: l10n.settingsHelpInviteHousematesDesc,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.actionGotIt),
            ),
          ],
        );
      },
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref, AppSettings settings) {
    showModalBottomSheet(
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
                  child: Text(l10n.languageSectionTitle,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                ListTile(
                  title: Text(l10n.languageMalay),
                  trailing: settings.language == 'ms'
                      ? Icon(Icons.check, color: context.colors.primary)
                      : null,
                  onTap: () {
                    ref.read(appSettingsProvider.notifier).setLanguage('ms');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: Text(l10n.languageEnglish),
                  trailing: settings.language == 'en'
                      ? Icon(Icons.check, color: context.colors.primary)
                      : null,
                  onTap: () {
                    ref.read(appSettingsProvider.notifier).setLanguage('en');
                    Navigator.pop(ctx);
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

  void _showCurrencyPicker(BuildContext context, WidgetRef ref, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SpringSheet(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(AppLocalizations.of(ctx).settingsCurrency,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              // Each entry is a currency CODE with its symbol — a stored value
              // and a proper noun, so it is shown exactly as stored in both
              // locales and never translated.
              ListTile(
                title: const Text('MYR (RM)'),
                trailing: settings.currency == 'MYR'
                    ? Icon(Icons.check, color: context.colors.primary)
                    : null,
                onTap: () {
                  ref.read(appSettingsProvider.notifier).setCurrency('MYR');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('SGD (S\$)'),
                trailing: settings.currency == 'SGD'
                    ? Icon(Icons.check, color: context.colors.primary)
                    : null,
                onTap: () {
                  ref.read(appSettingsProvider.notifier).setCurrency('SGD');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('USD (\$)'),
                trailing: settings.currency == 'USD'
                    ? Icon(Icons.check, color: context.colors.primary)
                    : null,
                onTap: () {
                  ref.read(appSettingsProvider.notifier).setCurrency('USD');
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Web only: shows whether this browser can receive push notifications and
/// offers an Enable button that requests permission from a user tap, then
/// registers the device token for the signed-in user.
class _PushDeviceTile extends StatefulWidget {
  const _PushDeviceTile();

  @override
  State<_PushDeviceTile> createState() => _PushDeviceTileState();
}

class _PushDeviceTileState extends State<_PushDeviceTile> {
  AuthorizationStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    PushNotificationService.instance.permissionStatus().then((s) {
      if (mounted) setState(() => _status = s);
    });
  }

  bool get _granted =>
      _status == AuthorizationStatus.authorized ||
      _status == AuthorizationStatus.provisional;

  Future<void> _enable() async {
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final status = await PushNotificationService.instance.enableFromUserGesture();
    if (!mounted) return;
    setState(() {
      _status = status;
      _busy = false;
    });
    if (_granted) {
      SnackbarUtils.showSuccess(context, l10n.settingsPushEnabledToast);
    } else if (status == AuthorizationStatus.denied) {
      SnackbarUtils.showError(context, l10n.settingsPushStatusBlocked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final String subtitle;
    if (_granted) {
      subtitle = l10n.settingsPushStatusOn;
    } else if (_status == AuthorizationStatus.denied) {
      subtitle = l10n.settingsPushStatusBlocked;
    } else {
      subtitle = l10n.settingsPushStatusOff;
    }

    return ListTile(
      leading: Icon(
        _granted
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
      ),
      title: Text(l10n.settingsPushThisDevice),
      subtitle: Text(subtitle),
      trailing: _granted || _status == null
          ? null
          : TextButton(
              onPressed: _busy ? null : _enable,
              child: Text(l10n.settingsPushEnable),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
      ),
    );
  }
}

/// The human label for a persisted appearance mode.
///
/// Top-level rather than private so a test can pin the exact wording the
/// Appearance row shows for each stored [ThemeMode].
///
/// [l10n] carries the selected language, so the label follows a runtime
/// language switch; it stays optional so the wording remains pinnable (in the
/// app's baseline language) without a localization context.
String themeModeLabel(ThemeMode mode, [AppLocalizations? l10n]) => switch (mode) {
      ThemeMode.system => l10n?.settingsThemeSystem ?? 'System default',
      ThemeMode.light => l10n?.settingsThemeLight ?? 'Light',
      ThemeMode.dark => l10n?.settingsThemeDark ?? 'Dark',
    };

class _HelpItem extends StatelessWidget {
  const _HelpItem({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
