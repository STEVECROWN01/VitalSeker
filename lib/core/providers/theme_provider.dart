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
  
  /// Defaults to [ThemeMode.dark] for new users — the app's primary aesthetic
  /// is a dark "clinical" UI, so first-launch users should land in dark mode.
  /// Once `loadTheme()` resolves (or the user manually picks a mode via
  /// `setTheme`), this initial value is replaced with the persisted choice.
  ThemeModeNotifier(this._ref) : super(ThemeMode.dark);

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
      // 'system' (the default in UserProfile) and any unrecognized value
      // fall back to dark — the app's first-launch / out-of-the-box default.
      // Users can still pick Light explicitly via Settings → Appearance.
      default: return ThemeMode.dark;
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
