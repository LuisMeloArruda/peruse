import 'package:schemantic/schemantic.dart';

part 'translation_schema.g.dart';

@Schema()
abstract class $TranslationOutput {
  String get translatedText;

  String get sourceLanguage;

  String get targetLanguage;
}
