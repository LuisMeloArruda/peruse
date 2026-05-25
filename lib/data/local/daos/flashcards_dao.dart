import 'package:drift/drift.dart';

import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/data/local/tables/flashcards_table.dart';

part 'flashcards_dao.g.dart';

@DriftAccessor(tables: [FlashcardsTable])
class FlashcardsDao extends DatabaseAccessor<AppDatabase>
    with _$FlashcardsDaoMixin {
  FlashcardsDao(super.db);

  Stream<List<LocalFlashcard>> watchFlashcardsForDeck(String deckId) {
    return (select(flashcardsTable)
          ..where(
            (t) => t.deckId.equals(deckId) & t.isDeleted.equals(false),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch();
  }

  Future<List<LocalFlashcard>> getFlashcardsForDeck(String deckId) {
    return (select(flashcardsTable)
          ..where(
            (t) => t.deckId.equals(deckId) & t.isDeleted.equals(false),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  Future<LocalFlashcard?> getFlashcardById(String id) {
    return (select(flashcardsTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<LocalFlashcard>> getFlashcardsByWordId(String wordId) {
    return (select(flashcardsTable)..where((t) => t.wordId.equals(wordId)))
        .get();
  }

  Future<List<LocalFlashcard>> getFlashcardsForDeckAndWord(
    String deckId,
    String wordId,
  ) {
    return (select(flashcardsTable)
          ..where(
            (t) => t.deckId.equals(deckId) & t.wordId.equals(wordId),
          ))
        .get();
  }

  Future<List<LocalFlashcard>> getUnsyncedFlashcards() {
    return (select(flashcardsTable)..where((t) => t.synced.equals(false))).get();
  }

  Future<void> upsertFlashcards(
    List<FlashcardsTableCompanion> companions,
  ) async {
    if (companions.isEmpty) return;

    await batch((batch) {
      batch.insertAll(
        flashcardsTable,
        companions,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> updateSyncStatus(String id, bool synced) async {
    await (update(flashcardsTable)..where((t) => t.id.equals(id))).write(
      FlashcardsTableCompanion(synced: Value(synced)),
    );
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(flashcardsTable)..where((t) => t.id.equals(id))).write(
      FlashcardsTableCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(BigInt.from(now)),
        synced: const Value(false),
      ),
    );
  }
}