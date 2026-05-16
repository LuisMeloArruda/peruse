import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:peruse/data/local/daos/decks_dao.dart';
import 'package:peruse/data/local/daos/words_dao.dart';
import 'package:peruse/data/local/tables/deck_words_table.dart';
import 'package:peruse/data/local/tables/decks_table.dart';
import 'package:peruse/data/local/tables/word_details_table.dart';
import 'package:peruse/data/local/tables/words_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    DecksTable,
    WordsTable,
    WordDetailsTable,
    DeckWordsTable,
  ],
  daos: [
    DecksDao,
    WordsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(wordsTable);
            await m.createTable(wordDetailsTable);
            await m.createTable(deckWordsTable);
          }
          if (from < 3) {
            await m.addColumn(wordsTable, wordsTable.synced);
            await m.addColumn(deckWordsTable, deckWordsTable.synced);
          }
        },
      );

  Future<void> clearUserData() async {
    await transaction(() async {
      await delete(deckWordsTable).go();
      await delete(wordDetailsTable).go();
      await delete(wordsTable).go();
      await delete(decksTable).go();
    });

    await _tryDeleteTable('captures');
    await _tryDeleteTable('object_labels');
  }

  Future<void> _tryDeleteTable(String tableName) async {
    try {
      await customStatement('DELETE FROM $tableName');
    } catch (_) {
      // Table might not exist in the local schema yet.
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(directory.path, 'peruse.sqlite');
    return NativeDatabase(File(dbPath));
  });
}
