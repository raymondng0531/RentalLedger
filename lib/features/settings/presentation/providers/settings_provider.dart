import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/preferences_service.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../features/authentication/presentation/providers/auth_provider.dart';

/// App settings state.
class AppSettings {
  const AppSettings({
    this.language = 'ms',
    this.currency = 'MYR',
    this.notificationsEnabled = true,
    this.themeMode = ThemeMode.system,
  });

  final String language;
  final String currency;
  final bool notificationsEnabled;

  /// The selected appearance mode: system, light, or dark.
  ///
  /// Defaults to [ThemeMode.system] so a first-time user follows their
  /// device/browser theme.
  final ThemeMode themeMode;

  /// Compatibility getter for the pre-existing boolean flag.
  ///
  /// The old `darkMode` field was never persisted and only ever drove a
  /// "coming soon" placeholder. It is now derived from [themeMode] so existing
  /// readers keep working — note that it is `false` for both [ThemeMode.light]
  /// and [ThemeMode.system]. New code should read [themeMode] directly.
  bool get darkMode => themeMode == ThemeMode.dark;

  AppSettings copyWith({
    String? language,
    String? currency,
    bool? notificationsEnabled,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      language: language ?? this.language,
      currency: currency ?? this.currency,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
        (ref) => AppSettingsNotifier(ref.watch(preferencesServiceProvider)));

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  /// Hydrates from local storage on construction.
  ///
  /// The store is read once, synchronously, so the very first frame already
  /// carries the persisted appearance — no light-to-dark flash on launch.
  AppSettingsNotifier(PreferencesService preferences)
      : _preferences = preferences,
        super(AppSettings(themeMode: preferences.readThemeMode()));

  final PreferencesService _preferences;

  /// Selects the appearance mode and persists it locally.
  ///
  /// The write is fire-and-forget: the UI must not wait on a localStorage/disk
  /// write to repaint, and a failed write only costs the restored mode on the
  /// next launch — not correctness in this session.
  void setThemeMode(ThemeMode mode) {
    if (mode == state.themeMode) return;

    state = state.copyWith(themeMode: mode);
    unawaited(_preferences.writeThemeMode(mode));
  }

  /// Compatibility shim for the previous boolean setter.
  ///
  /// Retained so existing call sites keep compiling. Prefer [setThemeMode]:
  /// `false` here means an explicit **Light** choice, not "follow the system".
  void setDarkMode(bool darkMode) =>
      setThemeMode(darkMode ? ThemeMode.dark : ThemeMode.light);

  void setLanguage(String lang) => state = state.copyWith(language: lang);

  void setCurrency(String currency) {
    // Update the runtime symbol so every currency display follows the picker.
    CurrencyUtils.setCurrencyCode(currency);
    state = state.copyWith(currency: currency);
  }

  void setNotificationsEnabled(bool enabled) =>
      state = state.copyWith(notificationsEnabled: enabled);
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
