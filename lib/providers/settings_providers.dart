import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import 'service_providers.dart';

/// Préférences utilisateur locales (persistées).
@immutable
class AppSettings {
  const AppSettings({
    this.soundEnabled = true,
    this.notificationsEnabled = true,
    this.themeMode = ThemeMode.system,
    this.musicEnabled = false,
  });

  final bool soundEnabled;
  final bool notificationsEnabled;
  final ThemeMode themeMode;

  /// Boîte à musique pendant qu'on dessine (coupée par défaut).
  final bool musicEnabled;

  AppSettings copyWith({
    bool? soundEnabled,
    bool? notificationsEnabled,
    ThemeMode? themeMode,
    bool? musicEnabled,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
      musicEnabled: musicEnabled ?? this.musicEnabled,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(sharedPreferencesProvider));
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static AppSettings _read(SharedPreferences prefs) {
    return AppSettings(
      soundEnabled: prefs.getBool(AppConstants.prefSoundEnabled) ?? true,
      notificationsEnabled:
          prefs.getBool(AppConstants.prefNotificationsEnabled) ?? true,
      themeMode: _themeFromString(prefs.getString(AppConstants.prefThemeMode)),
      musicEnabled: prefs.getBool(AppConstants.prefMusicEnabled) ?? false,
    );
  }

  Future<void> setSoundEnabled(bool value) async {
    state = state.copyWith(soundEnabled: value);
    await _prefs.setBool(AppConstants.prefSoundEnabled, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    state = state.copyWith(notificationsEnabled: value);
    await _prefs.setBool(AppConstants.prefNotificationsEnabled, value);
  }

  Future<void> setMusicEnabled(bool value) async {
    state = state.copyWith(musicEnabled: value);
    await _prefs.setBool(AppConstants.prefMusicEnabled, value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(AppConstants.prefThemeMode, mode.name);
  }

  static ThemeMode _themeFromString(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
