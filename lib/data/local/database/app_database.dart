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

class LocalCaptures extends Table {
  TextColumn get id => text()();
  TextColumn get localPath => text()();
  TextColumn get remoteId => text().nullable()();
  IntColumn get status => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get uploadAttempts => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalCaptureLabels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get captureId => text().references(LocalCaptures, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  RealColumn get confidence => real()();
  TextColumn get language => text().withDefault(const Constant('en'))();
  TextColumn get bboxJson => text().nullable()();
}

@DriftDatabase(
  tables: [
    DecksTable,
    WordsTable,
    WordDetailsTable,
    DeckWordsTable,
    LocalCaptures,
    LocalCaptureLabels,
  ],
  daos: [
    DecksDao,
    WordsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

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
          if (from < 4) {
            await m.createTable(localCaptures);
            await m.createTable(localCaptureLabels);
          }
        },
      );

  Future<void> clearUserData() async {
    await transaction(() async {
      await delete(deckWordsTable).go();
      await delete(wordDetailsTable).go();
      await delete(wordsTable).go();
      await delete(decksTable).go();
      await delete(localCaptureLabels).go();
      await delete(localCaptures).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(directory.path, 'peruse.sqlite');
    return NativeDatabase(File(dbPath));
  });
}
