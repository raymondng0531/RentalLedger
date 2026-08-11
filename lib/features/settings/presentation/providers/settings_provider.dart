import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_utils.dart';
import '../../../../features/authentication/presentation/providers/auth_provider.dart';

/// App settings state.
class AppSettings {
  const AppSettings({
    this.language = 'ms',
    this.currency = 'MYR',
    this.notificationsEnabled = true,
    this.darkMode = false,
  });

  final String language;
  final String currency;
  final bool notificationsEnabled;
  final bool darkMode;

  AppSettings copyWith({
    String? language,
    String? currency,
    bool? notificationsEnabled,
    bool? darkMode,
  }) {
    return AppSettings(
      language: language ?? this.language,
      currency: currency ?? this.currency,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
        (ref) => AppSettingsNotifier());

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings());

  void setLanguage(String lang) => state = state.copyWith(language: lang);
  void setCurrency(String currency) {
    // Update the runtime symbol so every currency display follows the picker.
    CurrencyUtils.setCurrencyCode(currency);
    state = state.copyWith(currency: currency);
  }
  void setNotificationsEnabled(bool enabled) =>
      state = state.copyWith(notificationsEnabled: enabled);
  void setDarkMode(bool darkMode) => state = state.copyWith(darkMode: darkMode);
}

/// Current user profile data.
class ProfileData {
  const ProfileData({
    this.displayName,
    this.email,
    this.photoUrl,
    this.memberSince,
  });

  final String? displayName;
  final String? email;
  final String? photoUrl;
  final DateTime? memberSince;
}

final profileProvider = Provider<ProfileData?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  return ProfileData(
    displayName: user.displayName,
    email: user.email,
    photoUrl: user.photoUrl,
    memberSince: user.createdAt,
  );
});
