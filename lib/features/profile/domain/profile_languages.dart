import 'package:peruse/core/localization/app_base_translations.dart';

const profileLanguageTranslationKeys = <String, String>{
  'en': 'language_en',
  'pt': 'language_pt',
  'es': 'language_es',
  'fr': 'language_fr',
};

String profileLanguageTranslationKey(String languageCode) {
  return profileLanguageTranslationKeys[languageCode] ?? languageCode;
}

/// English display name for LLM prompts (not localized UI).
String profileLanguageLabel(String languageCode) {
  final key = profileLanguageTranslationKeys[languageCode];
  if (key == null) {
    return languageCode.toUpperCase();
  }
  return appBaseTranslations[key]!;
}
