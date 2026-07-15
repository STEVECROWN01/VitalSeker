import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import 'auth_provider.dart';
import 'user_profile_provider.dart';

/// FIX (audit H-2, H-3): the theme provider previously listened to
/// authStateProvider (which fires on every token refresh) and instantiated
/// a new DatabaseService() on each fire. We now:
///   1. Listen to currentUserProvider (deduplicates on user identity —
///      only fires when the user ID actually changes, not on token refresh).
///   2. Use ref.read(databaseServiceProvider) instead of new DatabaseService().
///   3. Use ref.read(userProfileProvider).valueOrNull for reads instead of
///      a direct DB call, so we benefit from the provider's cache.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final notifier = ThemeModeNotifier(ref);
  notifier.loadThemeFromLocal();
  // Listen to currentUserProvider (not authStateProvider) to avoid
  // firing on every token refresh.
  ref.listen(currentUserProvider, (previous, next) {
    if (previous?.id != next?.id) {
      notifier.loadTheme();
    }
  });
  return notifier;
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;

  ThemeModeNotifier(this._ref) : super(ThemeMode.system);

  Future<void> loadThemeFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString('theme_preference') ?? 'system';
      state = _themeFromString(themeStr);
    } catch (_) {}
  }

  Future<void> loadTheme() async {
    // FIX (audit H-3): use userProfileProvider instead of a direct DB call.
    final profile = _ref.read(userProfileProvider).valueOrNull;
    if (profile != null) {
      state = _themeFromString(profile.themePreference);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_preference', _themeToString(state));
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_preference', _themeToString(mode));
    } catch (_) {}
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final db = _ref.read(databaseServiceProvider);
      await db.updateUserProfile(user.id, {
        'theme_preference': _themeToString(mode),
      });
      _ref.invalidate(userProfileProvider);
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
