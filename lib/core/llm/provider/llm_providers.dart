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
