import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import 'auth_provider.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final notifier = ThemeModeNotifier(ref);
  // Load theme from local storage immediately (before auth resolves)
  notifier.loadThemeFromLocal();
  // Also load from DB when auth state changes
  ref.listen(authStateProvider, (_, __) {
    notifier.loadTheme();
  });
  return notifier;
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;
  
  ThemeModeNotifier(this._ref) : super(ThemeMode.system);

  /// Load theme from SharedPreferences (local, instant, works offline)
  Future<void> loadThemeFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString('theme_preference') ?? 'system';
      state = _themeFromString(themeStr);
    } catch (_) {}
  }

  Future<void> loadTheme() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final db = DatabaseService();
      final profile = await db.getUserProfile(user.id);
      if (profile != null) {
        state = _themeFromString(profile.themePreference);
        // Also save to local storage for instant load on next startup
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('theme_preference', _themeToString(state));
      }
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    // Save to local storage immediately (persists across app restarts)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_preference', _themeToString(mode));
    } catch (_) {}
    // Also save to DB if user is logged in
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final db = DatabaseService();
      await db.updateUserProfile(user.id, {
        'theme_preference': _themeToString(mode),
      });
    } catch (_) {}
  }

  ThemeMode _themeFromString(String theme) {
    switch (theme) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  String _themeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'light';
      case ThemeMode.dark: return 'dark';
      default: return 'system';
    }
  }
}
