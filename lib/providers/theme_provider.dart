import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama teması (koyu / açık) yöneticisi.
/// SharedPreferences ile seçim kalıcı olarak saklanır.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'app_dark_mode';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_key) ?? true;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setDark(bool isDark) async {
    if (_themeMode == (isDark ? ThemeMode.dark : ThemeMode.light)) return;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, isDark);
    } catch (_) {}
  }
}
