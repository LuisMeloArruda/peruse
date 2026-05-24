const supportedProfileLanguageCodes = <String>['en', 'pt', 'es', 'fr'];

const profileLanguageLabels = <String, String>{
  'en': 'English',
  'pt': 'Portuguese',
  'es': 'Spanish',
  'fr': 'French',
};

String profileLanguageLabel(String languageCode) {
  return profileLanguageLabels[languageCode] ?? languageCode.toUpperCase();
}