import 'package:drift/drift.dart';

@DataClassName('LocalDeck')
class DecksTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get bio => text().nullable()();
  TextColumn get userId => text()();
  TextColumn get color => text()();
  TextColumn get icon => text()();
  TextColumn get coverImageUrl => text().nullable()();
  Int64Column get createdAt => int64()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  // Tracks whether the row has been synced with the remote source.
  BoolColumn get isSynced => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
