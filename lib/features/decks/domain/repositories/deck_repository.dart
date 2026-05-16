import 'package:peruse/features/decks/domain/entities/deck.dart';
import 'package:peruse/features/decks/domain/entities/deck_word.dart';
import 'package:peruse/features/decks/domain/entities/word.dart';
import 'package:peruse/features/decks/domain/entities/word_details.dart';

abstract class IDeckRepository {
  Future<List<AppDeck>> getDecks();
  Stream<List<AppDeck>> watchDecks();
  Future<void> createDeck(AppDeck deck);
  Future<void> updateDeck(AppDeck deck);
  Future<void> deleteDeck(String id);

  Stream<AppDeck?> watchDeck(String deckId);
  Stream<List<AppWord>> watchDeckWords(String deckId);
  Future<AppWord?> getWordById(String wordId);
  Future<AppWordDetails?> getWordDetails(AppWord word);
  Future<void> createWordInDeck({
    required AppWord word,
    required String deckId,
  });
  Future<void> syncPendingWords();
  Future<void> fetchAndCacheUserData();

  Future<void> addWordToDeck(DeckWord deckWord);
  Future<void> removeWordFromDeck(String deckId, String wordId);
}
