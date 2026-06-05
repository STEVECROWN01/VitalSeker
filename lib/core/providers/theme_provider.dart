import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'auth_provider.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final notifier = ThemeModeNotifier(ref);
  // Load theme when auth state changes
  ref.listen(authStateProvider, (_, __) {
    notifier.loadTheme();
  });
  return notifier;
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;
  
  ThemeModeNotifier(this._ref) : super(ThemeMode.system);

  Future<void> loadTheme() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final db = DatabaseService();
      final profile = await db.getUserProfile(user.id);
      if (profile != null) {
        state = _themeFromString(profile.themePreference);
      }
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
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
