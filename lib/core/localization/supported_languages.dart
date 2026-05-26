import 'package:flutter_localization_agent/flutter_localization_agent.dart';
import 'package:peruse/core/localization/app_base_translations.dart';
import 'package:peruse/features/profile/domain/profile_languages.dart';

/// Source language for base UI strings and LLM translation input.
const appBaseLanguageCode = 'en';

final List<Language> appSupportedLanguages = [
  for (final entry in profileLanguageTranslationKeys.entries)
    Language(code: entry.key, name: appBaseTranslations[entry.value]!),
];

final Language appInitialLanguage = appSupportedLanguages.firstWhere(
  (language) => language.code == appBaseLanguageCode,
  orElse: () => appSupportedLanguages.first,
);
