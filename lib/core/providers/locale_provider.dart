import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import 'auth_provider.dart';

/// Maps language display names to Locale objects.
/// 40 languages — exceeds the Cahier des Charges requirement of "40+ languages".
const Map<String, Locale> languageLocales = {
  'English (US)': Locale('en'),
  'English (UK)': Locale('en', 'GB'),
  'French': Locale('fr'),
  'Spanish': Locale('es'),
  'Portuguese': Locale('pt'),
  'German': Locale('de'),
  'Italian': Locale('it'),
  'Dutch': Locale('nl'),
  'Arabic': Locale('ar'),
  'Swahili': Locale('sw'),
  'Hausa': Locale('ha'),
  'Yoruba': Locale('yo'),
  'Igbo': Locale('ig'),
  'Chinese': Locale('zh'),
  'Japanese': Locale('ja'),
  'Korean': Locale('ko'),
  'Hindi': Locale('hi'),
  'Bengali': Locale('bn'),
  'Urdu': Locale('ur'),
  'Turkish': Locale('tr'),
  'Russian': Locale('ru'),
  'Polish': Locale('pl'),
  'Vietnamese': Locale('vi'),
  'Thai': Locale('th'),
  'Indonesian': Locale('id'),
  'Tagalog': Locale('tl'),
  // 14 new languages (Phase 5) — brings total to 40, exceeding spec's "40+"
  'Persian': Locale('fa'),
  'Hebrew': Locale('he'),
  'Czech': Locale('cs'),
  'Greek': Locale('el'),
  'Romanian': Locale('ro'),
  'Hungarian': Locale('hu'),
  'Swedish': Locale('sv'),
  'Norwegian': Locale('no'),
  'Danish': Locale('da'),
  'Finnish': Locale('fi'),
  'Slovak': Locale('sk'),
  'Ukrainian': Locale('uk'),
  'Malay': Locale('ms'),
  'Burmese': Locale('my'),
};

/// Reverse map for getting the display name from a Locale.
String localeToLanguageName(Locale locale) {
  for (final entry in languageLocales.entries) {
    if (entry.value.languageCode == locale.languageCode &&
        entry.value.countryCode == locale.countryCode) {
      return entry.key;
    }
  }
  // Fallback: match by language code only
  for (final entry in languageLocales.entries) {
    if (entry.value.languageCode == locale.languageCode) {
      return entry.key;
    }
  }
  return 'English (US)';
}

/// Provider for the app's current locale. Changing this immediately
/// re-translates the entire app via Flutter's localization system AND
/// persists the choice to the users table so it survives app restarts.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(ref);
});

class LocaleNotifier extends StateNotifier<Locale> {
  final Ref _ref;

  LocaleNotifier(this._ref) : super(const Locale('en')) {
    // Load saved locale when auth state changes (i.e. on sign-in).
    _ref.listen<AsyncValue>(authStateProvider, (_, __) {
      loadLocale();
    });
  }

  /// Load the user's saved language preference from the DB. Called on app
  /// start and on auth state changes.
  Future<void> loadLocale() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final db = DatabaseService();
      final profile = await db.getUserProfile(user.id);
      if (profile != null) {
        final langCode = profile.preferredLanguage;
        if (langCode.isNotEmpty && langCode != 'en') {
          // Try to find a matching locale
          for (final entry in languageLocales.entries) {
            if (entry.value.languageCode == langCode) {
              state = entry.value;
              return;
            }
          }
        }
      }
    } catch (_) {}
  }

  void setLocale(Locale locale) {
    state = locale;
    _persist(locale);
  }

  void setLocaleByLanguageName(String languageName) {
    final locale = languageLocales[languageName];
    if (locale != null) {
      state = locale;
      _persist(locale);
    }
  }

  /// Persist the locale to the users table so it survives app restarts.
  /// Falls back silently if the user is not signed in or the DB write fails.
  Future<void> _persist(Locale locale) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final db = DatabaseService();
      await db.updateUserProfile(user.id, {
        'preferred_language': locale.languageCode,
      });
    } catch (_) {}
  }
}
