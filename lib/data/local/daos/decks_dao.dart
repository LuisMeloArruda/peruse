import 'package:drift/drift.dart';
import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/data/local/tables/decks_table.dart';

part 'decks_dao.g.dart';

@DriftAccessor(tables: [DecksTable])
class DecksDao extends DatabaseAccessor<AppDatabase> with _$DecksDaoMixin {
  DecksDao(super.db);

  Stream<List<LocalDeck>> watchDecks() {
    return select(decksTable).watch();
  }

  Future<List<LocalDeck>> getDecks() {
    return select(decksTable).get();
  }

  Future<void> upsertDeck(DecksTableCompanion companion) async {
    await into(decksTable).insert(
      companion,
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> updateSyncStatus(String id, bool isSynced) async {
    await (update(decksTable)..where((t) => t.id.equals(id))).write(
      DecksTableCompanion(isSynced: Value(isSynced)),
    );
  }

  Future<void> deleteDeck(String id) async {
    await (delete(decksTable)..where((t) => t.id.equals(id))).go();
  }

  Future<List<LocalDeck>> getUnsyncedDecks() {
    return (select(decksTable)..where((t) => t.isSynced.equals(false))).get();
  }

  Future<void> upsertDecks(List<DecksTableCompanion> companions) async {
    await batch((batch) {
      batch.insertAll(
        decksTable,
        companions,
        mode: InsertMode.insertOrReplace,
      );
    });
  }
}
