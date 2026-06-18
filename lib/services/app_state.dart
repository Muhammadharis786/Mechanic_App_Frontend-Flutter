import 'package:flutter/material.dart';
import 'app_preferences.dart';

class AppThemeController extends ValueNotifier<ThemeMode> {
  AppThemeController() : super(ThemeMode.light);

  Future<void> load() async {
    final savedMode = await AppPreferences.getThemeMode();
    if (savedMode == 'light') {
      value = ThemeMode.light;
    } else if (savedMode == 'dark') {
      value = ThemeMode.dark;
    }
  }

  Future<void> setDark() async {
    value = ThemeMode.dark;
    await AppPreferences.setThemeMode('dark');
  }

  Future<void> setLight() async {
    value = ThemeMode.light;
    await AppPreferences.setThemeMode('light');
  }
}

class AppLanguageController extends ValueNotifier<Locale> {
  AppLanguageController() : super(const Locale('en'));

  Future<void> load() async {
    final savedCode = await AppPreferences.getLanguageCode();
    if (savedCode == 'ur') {
      value = const Locale('ur');
    } else {
      value = const Locale('en');
    }
  }

  Future<void> setEnglish() async {
    value = const Locale('en');
    await AppPreferences.setLanguageCode('en');
  }

  Future<void> setUrdu() async {
    value = const Locale('ur');
    await AppPreferences.setLanguageCode('ur');
  }
}

final appThemeController = AppThemeController();
final appLanguageController = AppLanguageController();