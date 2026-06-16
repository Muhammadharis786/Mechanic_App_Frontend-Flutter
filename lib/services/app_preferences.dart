import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const String themeModeKey = 'app_theme_mode';
  static const String languageCodeKey = 'app_language_code';

  static Future<SharedPreferences> _prefs() async {
    return SharedPreferences.getInstance();
  }

  static Future<String?> getThemeMode() async {
    final prefs = await _prefs();
    return prefs.getString(themeModeKey);
  }

  static Future<void> setThemeMode(String mode) async {
    final prefs = await _prefs();
    await prefs.setString(themeModeKey, mode);
  }

  static Future<String?> getLanguageCode() async {
    final prefs = await _prefs();
    return prefs.getString(languageCodeKey);
  }

  static Future<void> setLanguageCode(String code) async {
    final prefs = await _prefs();
    await prefs.setString(languageCodeKey, code);
  }
}