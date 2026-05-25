import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';

final wordAudioUrlProvider = FutureProvider.family<String?, String>(
  (ref, wordId) async {
    final repository = ref.watch(deckRepositoryProvider);
    final word = await repository.getWordById(wordId);
    if (word == null) {
      return null;
    }

    final details = await repository.getWordDetails(word);
    final audioUrl = details?.audioUrl.trim() ?? '';
    return audioUrl.isEmpty ? null : audioUrl;
  },
);