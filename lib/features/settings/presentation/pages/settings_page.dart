import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/avatar_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/spring_sheet.dart';
import '../../../../features/authentication/presentation/providers/auth_provider.dart';
import '../../../../features/members/presentation/providers/house_provider.dart';
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // ── Profile header ──
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryGreen.withAlpha(30),
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
                                color: AppTheme.primaryGreen,
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
                        profile?.displayName ?? 'User',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        profile?.email ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push(RouteNames.profile),
                  tooltip: 'Edit Profile',
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── House Section ──
          _SectionHeader(title: 'House'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('House Name'),
                  subtitle: Text(house?.houseName ?? 'Not set'),
                ),
                if (house != null) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.vpn_key_outlined),
                    title: const Text('Invite Code'),
                    subtitle: Text(house.inviteCode),
                    trailing: const Icon(Icons.copy_rounded, size: 18),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: house.inviteCode));
                      SnackbarUtils.showSuccess(context, 'Invite code copied');
                    },
                  ),
                ],
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.people_outlined),
                  title: const Text('Members'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(RouteNames.members),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Account Section ──
          _SectionHeader(title: 'Account'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outlined),
                  title: const Text('Edit Profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(RouteNames.profile),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Appearance Section ──
          _SectionHeader(title: 'Appearance'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark Mode'),
              subtitle: const Text('Coming soon'),
              value: settings.darkMode,
              onChanged: (_) {
                SnackbarUtils.showInfo(context, 'Dark mode coming soon');
              },
            ),
          ),

          const SizedBox(height: 8),

          // ── Notifications Section ──
          _SectionHeader(title: 'Notifications'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive alerts for expense updates'),
              value: settings.notificationsEnabled,
              onChanged: (v) =>
                  ref.read(appSettingsProvider.notifier).setNotificationsEnabled(v),
            ),
          ),

          const SizedBox(height: 8),

          // ── Preferences Section ──
          _SectionHeader(title: 'Preferences'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Language'),
                  subtitle: Text(settings.language == 'ms' ? 'Bahasa Melayu' : 'English'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLanguagePicker(context, ref, settings),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.attach_money_outlined),
                  title: const Text('Currency'),
                  subtitle: Text(settings.currency),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCurrencyPicker(context, ref, settings),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Help Section ──
          _SectionHeader(title: 'Support'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help Center'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showHelpDialog(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('About'),
                  subtitle: const Text('Version 1.0.0'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Rental Ledger',
                      applicationVersion: '1.0.0',
                      applicationLegalese: 'A household finance management app.',
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
              leading: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
              title: const Text('Sign Out'),
              titleTextStyle: const TextStyle(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.w500,
              ),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
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
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help Center'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rental Ledger',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('Track shared household expenses with ease.'),
            SizedBox(height: 16),
            _HelpItem(
              icon: Icons.receipt_long_outlined,
              title: 'Submit Expenses',
              description: 'Tap + to add a new expense claim with receipt.',
            ),
            _HelpItem(
              icon: Icons.check_circle_outline,
              title: 'Treasurer Approval',
              description: 'The Treasurer reviews and approves expenses.',
            ),
            _HelpItem(
              icon: Icons.wallet_outlined,
              title: 'Reimbursements',
              description: 'Once approved and paid, you get reimbursed.',
            ),
            _HelpItem(
              icon: Icons.vpn_key_outlined,
              title: 'Invite Housemates',
              description: 'Share your invite code from the Members screen.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SpringSheet(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Language',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Bahasa Melayu'),
                trailing: settings.language == 'ms'
                    ? const Icon(Icons.check, color: AppTheme.primaryGreen)
                    : null,
                onTap: () {
                  ref.read(appSettingsProvider.notifier).setLanguage('ms');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('English'),
                trailing: settings.language == 'en'
                    ? const Icon(Icons.check, color: AppTheme.primaryGreen)
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
      ),
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
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Currency',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('MYR (RM)'),
                trailing: settings.currency == 'MYR'
                    ? const Icon(Icons.check, color: AppTheme.primaryGreen)
                    : null,
                onTap: () {
                  ref.read(appSettingsProvider.notifier).setCurrency('MYR');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('SGD (S\$)'),
                trailing: settings.currency == 'SGD'
                    ? const Icon(Icons.check, color: AppTheme.primaryGreen)
                    : null,
                onTap: () {
                  ref.read(appSettingsProvider.notifier).setCurrency('SGD');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('USD (\$)'),
                trailing: settings.currency == 'USD'
                    ? const Icon(Icons.check, color: AppTheme.primaryGreen)
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
              color: AppTheme.textSecondary,
            ),
      ),
    );
  }
}

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
          Icon(icon, size: 20, color: AppTheme.primaryGreen),
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
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
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
