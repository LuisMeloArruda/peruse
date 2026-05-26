import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peruse/core/llm/models/translation_schema.dart';

import '../models/llm_request.dart';
import '../services/llm_translation_service.dart';

final llmTranslationServiceProvider = Provider<LlmTranslationService>((ref) {
  final apiKey = dotenv.get('GEMINI_API_KEY');
  final service = LlmTranslationService(apiKey: apiKey);
  return service;
});

final llmTranslateProvider =
    FutureProvider.family<TranslationOutput, LlmRequest>((ref, request) {
      final service = ref.watch(llmTranslationServiceProvider);
      return service.translate(request);
    });

class TranslationCacheNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {};

  String? get(String key) => state[key];

  void put(String key, String value) {
    if (key.isEmpty) return;
    state = {...state, key: value};
  }
}

final llmTranslationCacheProvider =
    NotifierProvider<TranslationCacheNotifier, Map<String, String>>(
      TranslationCacheNotifier.new,
    );

String _llmCacheKey(String targetLanguage, String source) =>
    '\u0000$targetLanguage\u0000$source';

/// Public cache key helper for translations.
String llmCacheKey(String targetLanguage, String source) =>
    _llmCacheKey(targetLanguage, source);
