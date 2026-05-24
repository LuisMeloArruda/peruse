import 'package:drift/drift.dart';
import 'package:peruse/data/local/tables/study_sessions_table.dart';
import 'package:peruse/data/local/tables/words_table.dart';

@DataClassName('LocalStudyResult')
class StudyResultsTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get sessionId =>
      text().references(StudySessionsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get wordId => text().references(WordsTable, #id)();
  BoolColumn get isCorrect => boolean()();
  Int64Column get timeTaken => int64()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
