import 'package:flutter/material.dart';

/// Supported application languages for DriveMate
enum AppLanguage {
  en('en', 'English', 'English', TextDirection.ltr),
  bn('bn', 'Bengali', 'বাংলা', TextDirection.ltr),
  hi('hi', 'Hindi', 'हिन्दी', TextDirection.ltr),
  orLang('or', 'Odia', 'ଓଡ଼ିଆ', TextDirection.ltr),
  ur('ur', 'Urdu', 'اردو', TextDirection.rtl);

  final String code;
  final String englishName;
  final String nativeName;
  final TextDirection textDirection;

  const AppLanguage(
    this.code,
    this.englishName,
    this.nativeName,
    this.textDirection,
  );

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('bn'),
    Locale('hi'),
    Locale('or'),
    Locale('ur'),
  ];

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.en;
    final clean = code.toLowerCase().trim();
    for (final lang in AppLanguage.values) {
      if (lang.code == clean) return lang;
    }
    return AppLanguage.en;
  }

  static AppLanguage fromLocale(Locale locale) {
    return fromCode(locale.languageCode);
  }
}
