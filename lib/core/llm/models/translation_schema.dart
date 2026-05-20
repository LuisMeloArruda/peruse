import 'package:schemantic/schemantic.dart';

part 'translation_schema.g.dart';

@Schema()
abstract class $TranslationOutput {
  /// map of original words and their translation
  Map<String, String> get translatedTexts;

  String get sourceLanguage;

  String get targetLanguage;
}
