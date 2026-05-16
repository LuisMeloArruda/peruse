import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:peruse/data/local/daos/decks_dao.dart';
import 'package:peruse/data/local/tables/decks_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [DecksTable], daos: [DecksDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(directory.path, 'peruse.sqlite');
    return NativeDatabase(File(dbPath));
  });
}
