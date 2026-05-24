import 'package:drift/drift.dart';

@DataClassName('LocalProfile')
class ProfilesTable extends Table {
  TextColumn get userId => text()();
  TextColumn get preferredLanguage =>
      text().named('preferred_language').withDefault(const Constant('en'))();
  Int64Column get createdAt =>
      int64().named('created_at').withDefault(Constant(BigInt.from(0)))();
  Int64Column get updatedAt =>
      int64().named('updated_at').withDefault(Constant(BigInt.from(0)))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {userId};
}