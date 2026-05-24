import 'package:drift/drift.dart';
import 'package:peruse/data/local/tables/decks_table.dart';

@DataClassName('LocalStudySession')
class StudySessionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get deckId => text().references(DecksTable, #id)();
  TextColumn get mode => text()();
  Int64Column get startedAt => int64()();
  Int64Column get endedAt => int64().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
