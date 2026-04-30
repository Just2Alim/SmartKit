import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Toggle theme, save to SharedPreferences and Firestore (if logged in)
  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _saveThemeLocally(isDark);
    _saveThemeToFirestore(isDark);
    notifyListeners();
  }

  /// Load theme: first try Firestore (if logged in), else SharedPreferences
  Future<void> _loadTheme() async {
    // 1. Try local prefs first for instant startup
    final prefs = await SharedPreferences.getInstance();
    final localIsDark = prefs.getBool(_themeKey);
    if (localIsDark != null) {
      _themeMode = localIsDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }

    // 2. Then try Firestore for the logged-in user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          final firestoreIsDark = data?['isDarkTheme'] as bool?;
          if (firestoreIsDark != null) {
            _themeMode = firestoreIsDark ? ThemeMode.dark : ThemeMode.light;
            await prefs.setBool(_themeKey, firestoreIsDark);
            notifyListeners();
          }
        }
      } catch (_) {
        // Firestore unavailable — use local value
      }
    }
  }

  /// Re-load theme from Firestore after login
  Future<void> reloadFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        final firestoreIsDark = data?['isDarkTheme'] as bool?;
        if (firestoreIsDark != null) {
          _themeMode = firestoreIsDark ? ThemeMode.dark : ThemeMode.light;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_themeKey, firestoreIsDark);
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveThemeLocally(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  Future<void> _saveThemeToFirestore(bool isDark) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'isDarkTheme': isDark});
    } catch (_) {}
  }
}
