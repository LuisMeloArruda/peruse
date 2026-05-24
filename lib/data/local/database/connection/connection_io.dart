import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

LazyDatabase lazyOpenConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(directory.path, 'peruse.sqlite');
    final dbFile = File(dbPath);
    final resetMarker = File(p.join(directory.path, 'peruse.sqlite.reset.v1'));

    if (!await resetMarker.exists()) {
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      await resetMarker.writeAsString('reset complete');
    }

    return NativeDatabase(dbFile);
  });
}