import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:peruse/features/decks/domain/entities/deck.dart';
import 'package:peruse/features/decks/domain/entities/word.dart';
import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';

part 'deck_detail_notifier.g.dart';

class DeckDetailState {
  const DeckDetailState({
    required this.deck,
    required this.words,
    required this.filteredWords,
    required this.searchQuery,
  });

  final AppDeck? deck;
  final List<AppWord> words;
  final List<AppWord> filteredWords;
  final String searchQuery;

  DeckDetailState copyWith({
    AppDeck? deck,
    List<AppWord>? words,
    List<AppWord>? filteredWords,
    String? searchQuery,
  }) {
    return DeckDetailState(
      deck: deck ?? this.deck,
      words: words ?? this.words,
      filteredWords: filteredWords ?? this.filteredWords,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  static const DeckDetailState initial = DeckDetailState(
    deck: null,
    words: [],
    filteredWords: [],
    searchQuery: '',
  );
}

@riverpod
class DeckDetailNotifier extends _$DeckDetailNotifier {
  StreamSubscription<AppDeck?>? _deckSubscription;
  StreamSubscription<List<AppWord>>? _wordsSubscription;

  @override
  DeckDetailState build(String deckId) {
    final repository = ref.watch(deckRepositoryProvider);

    _deckSubscription = repository.watchDeck(deckId).listen((deck) {
      state = state.copyWith(deck: deck);
    });

    _wordsSubscription = repository.watchDeckWords(deckId).listen((words) {
      final filtered = _filterWords(words, state.searchQuery);
      state = state.copyWith(words: words, filteredWords: filtered);
    });

    ref.onDispose(() {
      _deckSubscription?.cancel();
      _wordsSubscription?.cancel();
    });

    return DeckDetailState.initial;
  }

  void updateSearchQuery(String query) {
    final normalized = query.trim();
    final filtered = _filterWords(state.words, normalized);
    state = state.copyWith(searchQuery: normalized, filteredWords: filtered);
  }

  Future<void> addWord(String wordText, {String? imageUrl}) async {
    final repository = ref.read(deckRepositoryProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final word = AppWord(
      id: const Uuid().v4(),
      text: wordText,
      imageUrl: imageUrl,
      confidence: 0,
      sourceScanId: null,
      createdAt: now,
    );
    await repository.createWordInDeck(deckId: deckId, word: word);
  }

  List<AppWord> _filterWords(List<AppWord> words, String query) {
    if (query.isEmpty) {
      return words;
    }
    final lower = query.toLowerCase();
    return words
        .where((word) => word.text.toLowerCase().contains(lower))
        .toList();
  }
}
