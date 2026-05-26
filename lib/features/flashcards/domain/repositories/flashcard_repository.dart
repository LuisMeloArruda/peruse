import 'package:peruse/features/flashcards/domain/entities/flashcard.dart';

abstract class IFlashcardRepository {
  Stream<List<AppFlashcard>> watchDeckFlashcards(String deckId);
  Future<List<AppFlashcard>> getDeckFlashcards(String deckId);
  Future<void> upsertFlashcard(AppFlashcard flashcard);
  Future<void> deleteFlashcard(String flashcardId);
  Future<void> syncAll();
  Future<void> fetchAndCacheUserData();
}
