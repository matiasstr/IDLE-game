import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neural_idle/app/shared_preferences_provider.dart';

final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale?> {
  static const preferenceKey = 'app.language';

  @override
  Locale? build() {
    final code = ref.watch(sharedPreferencesProvider).getString(preferenceKey);
    if (code != null && (code == 'en' || code == 'es')) return Locale(code);
    return null;
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale != null && !const ['en', 'es'].contains(locale.languageCode)) {
      throw ArgumentError.value(
        locale,
        'locale',
        'Supported languages: en, es.',
      );
    }
    state = locale;
    final preferences = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await preferences.remove(preferenceKey);
    } else {
      await preferences.setString(preferenceKey, locale.languageCode);
    }
  }
}
