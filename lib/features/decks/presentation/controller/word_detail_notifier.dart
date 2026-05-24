import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/core/llm/models/llm_request.dart';
import 'package:peruse/core/llm/provider/llm_providers.dart';
import 'package:peruse/features/decks/domain/entities/word.dart';
import 'package:peruse/features/decks/domain/entities/word_details.dart';
import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';
import 'package:peruse/features/profile/domain/profile_languages.dart';
import 'package:peruse/features/profile/presentation/controller/profile_notifier.dart';

part 'word_detail_notifier.g.dart';

class WordDetailState {
  const WordDetailState({
    required this.word,
    required this.details,
    required this.definitionText,
  });

  final AppWord word;
  final AppWordDetails? details;
  final String definitionText;
}

@riverpod
class WordDetailNotifier extends _$WordDetailNotifier {
  @override
  Future<WordDetailState> build(String wordId) async {
    final repository = ref.watch(deckRepositoryProvider);
    final profileState = ref.watch(profileProvider);
    _listenForConnectivity(wordId);

    final word = await repository.getWordById(wordId);
    if (word == null) {
      throw StateError('Word not found');
    }

    final details = await repository.getWordDetails(word);
    if (details == null) {
      debugPrint('No dictionary details found for ${word.text}.');
    }

    final preferredLanguageCode =
        profileState.asData?.value?.preferredLanguage ?? 'en';
    final definitionText = await _resolveDefinitionText(
      details,
      preferredLanguageCode,
    );

    return WordDetailState(
      word: word,
      details: details,
      definitionText: definitionText,
    );
  }

  void _listenForConnectivity(String wordId) {
    ref.listen(connectivityStatusProvider, (previous, next) {
      final prevList = previous?.value ?? const <ConnectivityResult>[];
      final nextList = next.value ?? const <ConnectivityResult>[];
      final wasOffline = prevList.contains(ConnectivityResult.none);
      final isOnline =
          nextList.isNotEmpty && !nextList.contains(ConnectivityResult.none);

      if (wasOffline && isOnline) {
        unawaited(ref.read(deckRepositoryProvider).syncPendingWords());
        _retryEnrichment(wordId);
      }
    });
  }

  Future<void> _retryEnrichment(String wordId) async {
    final current = state.value;
    if (current == null) return;

    final preferredLanguageCode =
        ref.read(profileProvider).asData?.value?.preferredLanguage ?? 'en';

    if (!_needsDefinitionTranslation(current, preferredLanguageCode)) {
      return;
    }

    final repository = ref.read(deckRepositoryProvider);
    final details = await repository.getWordDetails(current.word);
    if (details == null) return;

    final definitionText = await _resolveDefinitionText(
      details,
      preferredLanguageCode,
    );

    state = AsyncValue.data(
      WordDetailState(
        word: current.word,
        details: details,
        definitionText: definitionText,
      ),
    );
  }

  Future<String> _resolveDefinitionText(
    AppWordDetails? details,
    String preferredLanguageCode,
  ) async {
    if (details == null) {
      return 'No definition available yet.';
    }

    if (preferredLanguageCode == 'en') {
      return details.definition;
    }
    final targetLanguage = profileLanguageLabel(preferredLanguageCode).toLowerCase();
    final cacheKey = llmCacheKey(targetLanguage, details.definition);

    final cache = ref.read(llmTranslationCacheProvider);
    if (cache.containsKey(cacheKey)) {
      return cache[cacheKey]!;
    }

    try {
      final request = LlmRequest(
        input: {details.definition: 1},
        sourceLanguage: 'english',
        targetLanguage: targetLanguage,
      );
      final output = await ref
          .read(llmTranslateProvider(request).future)
          .timeout(const Duration(seconds: 8));

      if (output.translatedTexts.isEmpty) {
        return details.definition;
      }

      final translated = output.translatedTexts.values.first;
      ref.read(llmTranslationCacheProvider.notifier).put(cacheKey, translated);
      return translated;
    } catch (error) {
      debugPrint('Definition translation failed, using English definition: $error');
      return details.definition;
    }
  }

  bool _needsDefinitionTranslation(
    WordDetailState current,
    String preferredLanguageCode,
  ) {
    if (preferredLanguageCode == 'en') {
      return false;
    }

    final details = current.details;
    if (details == null) {
      return false;
    }

    return current.definitionText.trim() == details.definition.trim();
  }
}
