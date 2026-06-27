import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Maps language display names to Locale objects.
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
/// re-translates the entire app via Flutter's localization system.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en'));

  void setLocale(Locale locale) {
    state = locale;
  }

  void setLocaleByLanguageName(String languageName) {
    final locale = languageLocales[languageName];
    if (locale != null) {
      state = locale;
    }
  }
}
