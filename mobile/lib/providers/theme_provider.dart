import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'app_theme_mode';
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  bool get isSystem => _mode == ThemeMode.system;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key) ?? 'light';
    if (saved == 'dark') {
      _mode = ThemeMode.dark;
    } else if (saved == 'system') {
      _mode = ThemeMode.system;
    } else {
      _mode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode newMode) async {
    _mode = newMode;
    final prefs = await SharedPreferences.getInstance();
    final str = newMode == ThemeMode.light
        ? 'light'
        : newMode == ThemeMode.system
            ? 'system'
            : 'dark';
    await prefs.setString(_key, str);
    notifyListeners();
  }

  Future<void> toggle() async {
    if (_mode == ThemeMode.dark) {
      await setMode(ThemeMode.light);
    } else {
      await setMode(ThemeMode.dark);
    }
  }

  Future<void> setDark() => setMode(ThemeMode.dark);
  Future<void> setLight() => setMode(ThemeMode.light);
  Future<void> setSystem() => setMode(ThemeMode.system);
}

