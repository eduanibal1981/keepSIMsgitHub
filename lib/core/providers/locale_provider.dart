import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:keep_sims/core/services/local_cache_service.dart';

part 'locale_provider.g.dart';

@riverpod
class LocaleController extends _$LocaleController {
  static const _localeKey = 'app_locale';

  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider).requireValue;
    final savedLocale = prefs.getString(_localeKey);
    if (savedLocale != null) {
      return Locale(savedLocale);
    }
    // Default to English
    return const Locale('en');
  }

  Future<void> setLocale(Locale newLocale) async {
    final prefs = ref.read(sharedPreferencesProvider).requireValue;
    await prefs.setString(_localeKey, newLocale.languageCode);
    state = newLocale;
  }
}
