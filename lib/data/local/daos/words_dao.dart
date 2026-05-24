import 'package:drift/drift.dart';
import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/data/local/tables/deck_words_table.dart';
import 'package:peruse/data/local/tables/word_details_table.dart';
import 'package:peruse/data/local/tables/words_table.dart';

part 'words_dao.g.dart';

@DriftAccessor(tables: [WordsTable, DeckWordsTable, WordDetailsTable])
class WordsDao extends DatabaseAccessor<AppDatabase> with _$WordsDaoMixin {
  WordsDao(super.db);

  Stream<List<LocalWord>> watchWordsForDeck(String deckId) {
    final query = select(wordsTable).join([
      innerJoin(deckWordsTable, deckWordsTable.wordId.equalsExp(wordsTable.id)),
    ])..where(deckWordsTable.deckId.equals(deckId));

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(wordsTable)).toList(),
    );
  }

  Future<LocalWord?> getWordById(String wordId) {
    return (select(
      wordsTable,
    )..where((t) => t.id.equals(wordId))).getSingleOrNull();
  }

  Future<LocalWordDetails?> getWordDetails(String wordId) {
    return (select(
      wordDetailsTable,
    )..where((t) => t.wordId.equals(wordId))).getSingleOrNull();
  }

  Future<void> upsertWordDetails(WordDetailsTableCompanion companion) async {
    await into(
      wordDetailsTable,
    ).insert(companion, mode: InsertMode.insertOrReplace);
  }

  Future<List<LocalWord>> getUnsyncedWords() {
    return (select(wordsTable)..where((t) => t.synced.equals(false))).get();
  }

  Future<void> updateWordSyncStatus(String wordId, bool synced) async {
    await (update(wordsTable)..where((t) => t.id.equals(wordId))).write(
      WordsTableCompanion(synced: Value(synced)),
    );
  }

  Future<void> updateWordConfidence(String wordId, double confidence) async {
    await (update(wordsTable)..where((t) => t.id.equals(wordId))).write(
      WordsTableCompanion(confidence: Value(confidence)),
    );
  }

  Future<void> updateWordImageUrl(String wordId, String? imageUrl) async {
    await (update(wordsTable)..where((t) => t.id.equals(wordId))).write(
      WordsTableCompanion(imageUrl: Value(imageUrl)),
    );
  }

  Future<void> upsertWords(List<WordsTableCompanion> companions) async {
    if (companions.isEmpty) return;

    await batch((batch) {
      batch.insertAll(wordsTable, companions, mode: InsertMode.insertOrReplace);
    });
  }

  Future<List<LocalDeckWord>> getUnsyncedDeckWords() {
    return (select(deckWordsTable)..where((t) => t.synced.equals(false))).get();
  }

  Future<void> upsertDeckWords(List<DeckWordsTableCompanion> companions) async {
    if (companions.isEmpty) return;

    await batch((batch) {
      batch.insertAll(
        deckWordsTable,
        companions,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> updateDeckWordSyncStatus(
    String deckId,
    String wordId,
    bool synced,
  ) async {
    await (update(deckWordsTable)
          ..where((t) => t.deckId.equals(deckId) & t.wordId.equals(wordId)))
        .write(DeckWordsTableCompanion(synced: Value(synced)));
  }

  Future<void> upsertWordDetailsList(
    List<WordDetailsTableCompanion> companions,
  ) async {
    if (companions.isEmpty) return;

    await batch((batch) {
      batch.insertAll(
        wordDetailsTable,
        companions,
        mode: InsertMode.insertOrReplace,
      );
    });
  }
}
