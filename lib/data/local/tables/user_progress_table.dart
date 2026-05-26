import 'package:drift/drift.dart';

@DataClassName('LocalUserProgress')
class UserProgressTable extends Table {
  TextColumn get userId => text()();
  IntColumn get totalWordsMastered =>
      integer().named('total_words_mastered').withDefault(const Constant(0))();
  IntColumn get currentStreak =>
      integer().named('current_streak').withDefault(const Constant(0))();
  Int64Column get lastStudyDate =>
      int64().named('last_study_date').withDefault(Constant(BigInt.from(0)))();
  RealColumn get lifetimeAccuracy =>
      real().named('lifetime_accuracy').withDefault(const Constant(0))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {userId};
}
