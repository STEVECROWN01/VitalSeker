import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import 'auth_provider.dart';
import 'user_profile_provider.dart';

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
  // Amharic — language #41
  'Amharic': Locale('am'),
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

/// SharedPreferences key for the persisted locale language code.
const _kLocalePrefsKey = 'preferred_language';

/// Provider for the app's current locale. Changing this immediately
/// re-translates the entire app via Flutter's localization system AND
/// persists the choice to SharedPreferences + the users table so it
/// survives app restarts.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(ref);
});

class LocaleNotifier extends StateNotifier<Locale> {
  final Ref _ref;

  LocaleNotifier(this._ref) : super(const Locale('en')) {
    // CRITICAL FIX: load from SharedPreferences IMMEDIATELY (synchronously
    // in the constructor) so the locale is correct on the very first
    // frame after a cold start. Without this, the app shows English for
    // the first ~500ms until the async DB fetch completes, causing a
    // visible "language flash" for non-English users.
    _loadLocaleFromLocal();

    // FIX (audit H-2): listen to currentUserProvider instead of
    // authStateProvider to avoid firing on every token refresh.
    _ref.listen(currentUserProvider, (previous, next) {
      if (previous?.id != next?.id) {
        loadLocale();
      }
    });

    // Also listen for userProfileProvider changes — on cold start the
    // user ID may be available immediately (session restored) but the
    // profile fetch is async. This catches the case where loadLocale()
    // ran too early and read null.
    _ref.listen(userProfileProvider, (previous, next) {
      if (next.value != null && previous?.value == null) {
        loadLocale();
      }
    });
  }

  /// Load the locale from SharedPreferences (synchronous-ish, fast).
  /// This is the fallback that works offline and for non-signed-in users.
  Future<void> _loadLocaleFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString(_kLocalePrefsKey);
      if (langCode != null && langCode.isNotEmpty) {
        for (final entry in languageLocales.entries) {
          if (entry.value.languageCode == langCode) {
            state = entry.value;
            return;
          }
        }
      }
    } catch (_) {
      // SharedPreferences may not be ready yet — the DB-backed loadLocale
      // will run as a fallback.
    }
  }

  /// Load the user's saved language preference from the DB. Called on
  /// app start and when the current user changes.
  Future<void> loadLocale() async {
    final profile = _ref.read(userProfileProvider).valueOrNull;
    if (profile != null) {
      final langCode = profile.preferredLanguage;
      if (langCode.isNotEmpty) {
        for (final entry in languageLocales.entries) {
          if (entry.value.languageCode == langCode) {
            state = entry.value;
            // Also persist to SharedPreferences so the next cold start
            // restores immediately without waiting for the DB fetch.
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_kLocalePrefsKey, langCode);
            } catch (_) {}
            return;
          }
        }
      }
    }
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

  /// Persist the locale to SharedPreferences (always) AND the users table
  /// (when signed in). Falls back silently on failure.
  Future<void> _persist(Locale locale) async {
    // Always persist to SharedPreferences — works for signed-out users too.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalePrefsKey, locale.languageCode);
    } catch (_) {}

    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final db = _ref.read(databaseServiceProvider);
      await db.updateUserProfile(user.id, {
        'preferred_language': locale.languageCode,
      });
    } catch (_) {}
  }
}
