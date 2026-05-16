import 'package:peruse/features/decks/domain/entities/deck.dart';
import 'package:peruse/features/decks/domain/entities/deck_word.dart';

abstract class IDeckRepository {
  Future<List<AppDeck>> getDecks();
  Stream<List<AppDeck>> watchDecks();
  Future<void> createDeck(AppDeck deck);
  Future<void> updateDeck(AppDeck deck);
  Future<void> deleteDeck(String id);

  Future<void> addWordToDeck(DeckWord deckWord);
  Future<void> removeWordFromDeck(String deckId, String wordId);
}
