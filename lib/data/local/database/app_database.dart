import 'package:drift/drift.dart';

import 'package:peruse/data/local/daos/decks_dao.dart';
import 'package:peruse/data/local/daos/flashcards_dao.dart';
import 'package:peruse/data/local/daos/profiles_dao.dart';
import 'package:peruse/data/local/daos/study_dao.dart';
import 'package:peruse/data/local/daos/words_dao.dart';
import 'package:peruse/data/local/database/connection/open_connection.dart';
import 'package:peruse/data/local/tables/daily_progress_table.dart';
import 'package:peruse/data/local/tables/deck_words_table.dart';
import 'package:peruse/data/local/tables/decks_table.dart';
import 'package:peruse/data/local/tables/flashcards_table.dart';
import 'package:peruse/data/local/tables/profiles_table.dart';
import 'package:peruse/data/local/tables/study_results_table.dart';
import 'package:peruse/data/local/tables/study_sessions_table.dart';
import 'package:peruse/data/local/tables/user_progress_table.dart';
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
  TextColumn get captureId =>
      text().references(LocalCaptures, #id, onDelete: KeyAction.cascade)();
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
    FlashcardsTable,
    StudySessionsTable,
    StudyResultsTable,
    UserProgressTable,
    DailyProgressTable,
    LocalCaptures,
    LocalCaptureLabels,
    ProfilesTable,
  ],
  daos: [DecksDao, WordsDao, FlashcardsDao, StudyDao, ProfilesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 13;

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
      if (from < 5) {
        await m.createTable(flashcardsTable);
      }
      if (from < 6) {
        await m.createTable(studySessionsTable);
        await m.createTable(studyResultsTable);
        await m.createTable(userProgressTable);
        await m.createTable(dailyProgressTable);
      }
      if (from < 7) {
        await m.database.customStatement(
          'DROP TABLE IF EXISTS study_sessions;',
        );
        await m.database.customStatement('DROP TABLE IF EXISTS study_results;');
        await m.database.customStatement('DROP TABLE IF EXISTS user_progress;');
        await m.database.customStatement(
          'DROP TABLE IF EXISTS daily_progress;',
        );
        await m.createTable(studySessionsTable);
        await m.createTable(studyResultsTable);
        await m.createTable(userProgressTable);
        await m.createTable(dailyProgressTable);
      }
      if (from < 8) {
        await m.addColumn(decksTable, decksTable.coverImageUrl);
      }
      if (from < 10) {
        await m.addColumn(decksTable, decksTable.bio);
      }
      if (from < 11) {
        await m.createTable(profilesTable);
      }
      if (from < 12) {
        await m.addColumn(decksTable, decksTable.isDeleted);
      }
      if (from < 13) {
        await m.addColumn(deckWordsTable, deckWordsTable.isDeleted);
      }
    },
  );

  Future<void> clearUserData() async {
    await transaction(() async {
      await delete(deckWordsTable).go();
      await delete(wordDetailsTable).go();
      await delete(wordsTable).go();
      await delete(decksTable).go();
      await delete(flashcardsTable).go();
      await delete(studyResultsTable).go();
      await delete(studySessionsTable).go();
      await delete(userProgressTable).go();
      await delete(dailyProgressTable).go();
      await delete(profilesTable).go();
      await delete(localCaptureLabels).go();
      await delete(localCaptures).go();
    });
  }
}

LazyDatabase _openConnection() {
  return openConnection();
}
