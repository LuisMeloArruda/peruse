import 'package:drift/drift.dart';
import 'package:peruse/data/local/tables/decks_table.dart';
import 'package:peruse/data/local/tables/words_table.dart';

@DataClassName('LocalDeckWord')
class DeckWordsTable extends Table {
  TextColumn get deckId => text().references(DecksTable, #id)();
  TextColumn get wordId => text().references(WordsTable, #id)();
  Int64Column get addedAt => int64()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {deckId, wordId};
}
