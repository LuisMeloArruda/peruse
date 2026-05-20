import 'dart:developer';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:peruse/core/llm/models/llm_request.dart';
import 'package:peruse/core/llm/models/translation_schema.dart';

class LlmTranslationService {
  final Genkit _ai;

  LlmTranslationService._(this._ai);

  factory LlmTranslationService({required String apiKey}) {
    final ai = Genkit(plugins: [googleAI(apiKey: apiKey)]);
    return LlmTranslationService._(ai);
  }

  Future<TranslationOutput> translate(LlmRequest request) async {
    try {
      final response = await _ai.generate(
        model: googleAI.gemini('gemini-2.5-flash'),
        messages: [
          Message(
            role: Role.system,
            content: [
              TextPart(
                text:
                    'You are a professional translator. '
                    'Translate the user\'s text into ${request.targetLanguage}. '
                    'Always detect the source language and set targetLanguage to "${request.targetLanguage}". '
                    'Respond only with the structured JSON — no explanations.',
              ),
            ],
          ),
          Message(
            role: Role.user,
            content: [
              TextPart(text: request.input.entries.map((e) => e.key).join(' ')),
            ],
          ),
        ],
        outputSchema: TranslationOutput.$schema,
      );
      final output = response.output;
      if (output == null) {
        throw StateError(
          'Translation failed: model returned no structured output.\n'
          'Raw text: ${response.text}',
        );
      }

      log(
        'Translated "${request.input}" → "${output.translatedTexts.values.join(', ')}"',
        name: 'LlmTranslationService',
      );

      return output;
    } catch (e) {
      log('Translation failed: ${e.toString()}', name: 'LlmTranslationService');
      throw Exception('Translation failed: ${e.toString()}');
    }
  }
}
