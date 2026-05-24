import 'package:drift/drift.dart';

@DataClassName('LocalDailyProgress')
class DailyProgressTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get date => text()();
  IntColumn get wordsStudied => integer().withDefault(const Constant(0))();
  IntColumn get correctAnswers => integer().withDefault(const Constant(0))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
