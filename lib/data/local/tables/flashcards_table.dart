import 'package:drift/drift.dart';
import 'package:peruse/data/local/tables/decks_table.dart';
import 'package:peruse/data/local/tables/words_table.dart';

@DataClassName('LocalFlashcard')
class FlashcardsTable extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text().references(DecksTable, #id)();
  TextColumn get wordId => text().references(WordsTable, #id)();
  TextColumn get frontText => text().nullable()();
  TextColumn get backText => text().nullable()();
  TextColumn get mediaUrl => text().nullable()();
  TextColumn get mediaType => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  Int64Column get revision => int64().withDefault(Constant(BigInt.zero))();
  TextColumn get modifiedBy => text().nullable()();
  Int64Column get createdAt => int64()();
  Int64Column get updatedAt => int64()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}