import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettingsState>(
      AppSettingsController.new,
    );

final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

enum AppLanguage {
  system(null),
  english('en'),
  chinese('zh'),
  japanese('ja');

  const AppLanguage(this.code);

  final String? code;

  Locale? get locale => code == null ? null : Locale(code!);

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (language) => language.code == code,
      orElse: () => AppLanguage.system,
    );
  }
}

enum AppThemePreference {
  system(null, ThemeMode.system),
  light('light', ThemeMode.light),
  dark('dark', ThemeMode.dark);

  const AppThemePreference(this.code, this.themeMode);

  final String? code;
  final ThemeMode themeMode;

  static AppThemePreference fromCode(String? code) {
    return AppThemePreference.values.firstWhere(
      (theme) => theme.code == code,
      orElse: () => AppThemePreference.system,
    );
  }
}

class AppSettingsState {
  const AppSettingsState({
    this.language = AppLanguage.system,
    this.theme = AppThemePreference.system,
  });

  final AppLanguage language;
  final AppThemePreference theme;

  Locale? get locale => language.locale;
  ThemeMode get themeMode => theme.themeMode;

  AppSettingsState copyWith({
    AppLanguage? language,
    AppThemePreference? theme,
  }) {
    return AppSettingsState(
      language: language ?? this.language,
      theme: theme ?? this.theme,
    );
  }
}

class AppSettingsController extends Notifier<AppSettingsState> {
  static const _languageKey = 'app.language';
  static const _themeKey = 'app.theme';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  AppSettingsState build() {
    Future<void>.microtask(_load);
    return const AppSettingsState();
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language);
    final code = language.code;
    if (code == null) {
      await _preferences.remove(_languageKey);
    } else {
      await _preferences.setString(_languageKey, code);
    }
  }

  Future<void> setTheme(AppThemePreference theme) async {
    state = state.copyWith(theme: theme);
    final code = theme.code;
    if (code == null) {
      await _preferences.remove(_themeKey);
    } else {
      await _preferences.setString(_themeKey, code);
    }
  }

  Future<void> _load() async {
    final code = await _preferences.getString(_languageKey);
    final themeCode = await _preferences.getString(_themeKey);
    state = state.copyWith(
      language: AppLanguage.fromCode(code),
      theme: AppThemePreference.fromCode(themeCode),
    );
  }
}
