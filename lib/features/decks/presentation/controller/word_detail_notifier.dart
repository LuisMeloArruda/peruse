import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/features/decks/domain/entities/word.dart';
import 'package:peruse/features/decks/domain/entities/word_details.dart';
import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';
import 'package:peruse/features/profile/presentation/controller/profile_notifier.dart';

part 'word_detail_notifier.g.dart';

class WordDetailState {
  const WordDetailState({
    required this.word,
    required this.details,
    required this.definitionText,
    required this.exampleText,
  });

  final AppWord word;
  final AppWordDetails? details;
  final String definitionText;
  final String exampleText;
}

@riverpod
class WordDetailNotifier extends _$WordDetailNotifier {
  @override
  Future<WordDetailState> build(String wordId) async {
    final repository = ref.watch(deckRepositoryProvider);
    _listenForConnectivity(wordId);

    final word = await repository.getWordById(wordId);
    if (word == null) {
      throw StateError('Word not found');
    }

    final details = await repository.getWordDetails(word);
    if (details == null) {
      debugPrint('No dictionary details found for ${word.text}.');
    }

    return WordDetailState(
      word: word,
      details: details,
      definitionText: details?.definition ?? '',
      exampleText: details?.example ?? '',
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

    state = AsyncValue.data(
      WordDetailState(
        word: current.word,
        details: details,
        definitionText: details.definition,
        exampleText: details.example,
      ),
    );
  }

  // Future<String> _resolveDefinitionText(
  //   AppWordDetails? details,
  //   String preferredLanguageCode,
  // ) async {
  //   if (details == null) {
  //     return appBaseTranslations['no_definition_available_yet']!;
  //   }

  //   if (preferredLanguageCode == 'en') {
  //     return details.definition;
  //   }
  //   final targetLanguage = profileLanguageLabel(
  //     preferredLanguageCode,
  //   ).toLowerCase();
  //   final cacheKey = llmCacheKey(targetLanguage, details.definition);

  //   final cache = ref.read(llmTranslationCacheProvider);
  //   if (cache.containsKey(cacheKey)) {
  //     return cache[cacheKey]!;
  //   }

  //   try {
  //     final request = LlmRequest(
  //       input: {details.definition: 1},
  //       sourceLanguage: 'english',
  //       targetLanguage: targetLanguage,
  //     );
  //     final output = await ref
  //         .read(llmTranslateProvider(request).future)
  //         .timeout(const Duration(seconds: 10));

  //     if (output.translatedTexts.isEmpty) {
  //       return details.definition;
  //     }

  //     final translated = output.translatedTexts.values.first;
  //     ref.read(llmTranslationCacheProvider.notifier).put(cacheKey, translated);
  //     return translated;
  //   } catch (error) {
  //     debugPrint(
  //       'Definition translation failed, using English definition: $error',
  //     );
  //     return details.definition;
  //   }
  // }

  // Future<String> _resolveExampleText(
  //   AppWordDetails? details,
  //   String preferredLanguageCode,
  // ) async {
  //   if (details == null) {
  //     return '';
  //   }

  //   final example = details.example.trim();
  //   if (example.isEmpty || preferredLanguageCode == 'en') {
  //     return example;
  //   }

  //   final targetLanguage = profileLanguageLabel(
  //     preferredLanguageCode,
  //   ).toLowerCase();
  //   final cacheKey = llmCacheKey(targetLanguage, example);

  //   final cache = ref.read(llmTranslationCacheProvider);
  //   if (cache.containsKey(cacheKey)) {
  //     return cache[cacheKey]!;
  //   }

  //   try {
  //     final request = LlmRequest(
  //       input: {example: 1},
  //       sourceLanguage: 'english',
  //       targetLanguage: targetLanguage,
  //     );
  //     final output = await ref
  //         .read(llmTranslateProvider(request).future)
  //         .timeout(const Duration(seconds: 8));

  //     if (output.translatedTexts.isEmpty) {
  //       return example;
  //     }

  //     final translated = output.translatedTexts.values.first;
  //     ref.read(llmTranslationCacheProvider.notifier).put(cacheKey, translated);
  //     return translated;
  //   } catch (error) {
  //     debugPrint('Example translation failed, using English example: $error');
  //     return example;
  //   }
  // }

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

    return current.definitionText.trim() == details.definition.trim() &&
        current.exampleText.trim() == details.example.trim();
  }
}
