import 'package:drift/drift.dart';
import 'package:peruse/data/local/tables/words_table.dart';

@DataClassName('LocalWordDetails')
class WordDetailsTable extends Table {
  TextColumn get wordId => text().references(WordsTable, #id)();
  TextColumn get definition => text()();
  TextColumn get example => text()();
  TextColumn get partOfSpeech => text()();
  TextColumn get phonetic => text()();
  TextColumn get audioUrl => text()();
  TextColumn get rawJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {wordId};
}
