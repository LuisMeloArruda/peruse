import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class LocalCaptures extends Table {
  TextColumn get id => text()();
  TextColumn get localPath => text()();
  TextColumn get remoteId => text().nullable()();
  IntColumn get status => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get uploadAttempts => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalCaptureLabels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get captureId =>
      text().references(LocalCaptures, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  RealColumn get confidence => real()();
  TextColumn get language => text().withDefault(const Constant('en'))();
  TextColumn get bboxJson => text().nullable()();
}

@DriftDatabase(tables: [LocalCaptures, LocalCaptureLabels])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < to) {
        // Basic fallback: ensure all tables/columns exist when upgrading.
        // For more complex migrations, add specific steps per version.
        await m.createAll();
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'peruse.sqlite'));
    return NativeDatabase(file);
  });
}
