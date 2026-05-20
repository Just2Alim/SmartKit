import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ThemeProvider extends ChangeNotifier {
  static final ThemeProvider instance = ThemeProvider._internal();

  static const String _themeKey = 'isDarkTheme';

  // Default: light theme
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider._internal() {
    _loadTheme();
  }

  /// Toggle theme, save to SharedPreferences and Supabase (if logged in)
  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _saveThemeLocally(isDark);
    _saveThemeToSupabase(isDark);
    notifyListeners();
  }

  /// Load theme: first try local prefs, then Supabase if logged in.
  Future<void> _loadTheme() async {
    // 1. Try local prefs first for instant startup
    final prefs = await SharedPreferences.getInstance();
    final localIsDark = prefs.getBool(_themeKey);
    if (localIsDark != null) {
      _themeMode = localIsDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data =
            await Supabase.instance.client
                .from('profiles')
                .select('is_dark_theme')
                .eq('id', user.id)
                .maybeSingle();
        final remoteIsDark = data?['is_dark_theme'] as bool?;
        if (remoteIsDark != null) {
          _themeMode = remoteIsDark ? ThemeMode.dark : ThemeMode.light;
          await prefs.setBool(_themeKey, remoteIsDark);
          notifyListeners();
        }
      } catch (_) {
        // Remote theme unavailable; keep local value.
      }
    }
  }

  /// Re-load theme from Supabase after login.
  Future<void> reloadFromSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data =
          await Supabase.instance.client
              .from('profiles')
              .select('is_dark_theme')
              .eq('id', user.id)
              .maybeSingle();
      final remoteIsDark = data?['is_dark_theme'] as bool?;
      if (remoteIsDark != null) {
        _themeMode = remoteIsDark ? ThemeMode.dark : ThemeMode.light;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_themeKey, remoteIsDark);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveThemeLocally(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  Future<void> _saveThemeToSupabase(bool isDark) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_dark_theme': isDark})
          .eq('id', user.id);
    } catch (_) {}
  }
}
