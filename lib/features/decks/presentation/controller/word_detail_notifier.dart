import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/features/decks/domain/entities/word.dart';
import 'package:peruse/features/decks/domain/entities/word_details.dart';
import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';

part 'word_detail_notifier.g.dart';

class WordDetailState {
  const WordDetailState({required this.word, required this.details});

  final AppWord word;
  final AppWordDetails? details;
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

    return WordDetailState(word: word, details: details);
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

    if (!_isDetailsIncomplete(current.details)) {
      return;
    }

    final repository = ref.read(deckRepositoryProvider);
    final details = await repository.getWordDetails(current.word);
    if (details == null) return;

    state = AsyncValue.data(
      WordDetailState(word: current.word, details: details),
    );
  }

  bool _isDetailsIncomplete(AppWordDetails? details) {
    if (details == null) return true;
    return details.definition.trim().isEmpty ||
        details.partOfSpeech.trim().isEmpty ||
        details.phonetic.trim().isEmpty;
  }
}
