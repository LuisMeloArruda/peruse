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
      log("LOG::${request.input.toString()}\n${request.sourceLanguage}\n${request.targetLanguage}",name: "request data");
      final response = await _ai.generate(
        model: googleAI.gemini('gemini-3.5-flash'),
        messages: [
          Message(
            role: Role.system,
            content: [
              TextPart(
                text:
                    'You are a professional translator for a language-learning app.\n\n'
                    'Translate each term in the user message from ${request.sourceLanguage} '
                    'into ${request.targetLanguage}.\n\n'
                    'Output rules:\n'
                    '- translatedTexts: map every input term to its translation. '
                    'Keys must match the original term exactly (same spelling and casing). '
                    'Do not omit, merge, split, or invent keys.\n'
                    '- sourceLanguage: detected input language (use "${request.sourceLanguage}" '
                    'when the input is in that language).\n'
                    '- targetLanguage: always "${request.targetLanguage}".\n\n'
                    'Quality:\n'
                    '- Use natural, concise wording suitable for vocabulary flashcards.\n'
                    '- For ambiguous labels (e.g. image tags), prefer the most common everyday meaning.\n'
                    '- Preserve proper nouns and untranslatable terms when appropriate.',
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
        'Translated "${request.input}" → "${output.toString()}"',
        name: 'LlmTranslationService',
      );

      return output;
    } catch (e) {
      log('Translation failed: ${e.toString()}', name: 'LlmTranslationService');
      throw Exception('Translation failed: ${e.toString()}');
    }
  }
}
