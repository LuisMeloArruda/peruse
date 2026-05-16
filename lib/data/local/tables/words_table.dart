import 'package:drift/drift.dart';

@DataClassName('LocalWord')
class WordsTable extends Table {
  TextColumn get id => text()();
  TextColumn get wordText => text()();
  TextColumn get imageUrl => text().nullable()();
  RealColumn get confidence => real().withDefault(const Constant(0))();
  TextColumn get sourceScanId => text().nullable()();
  Int64Column get createdAt => int64()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
