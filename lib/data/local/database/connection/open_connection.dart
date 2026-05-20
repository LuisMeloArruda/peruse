import 'package:drift/drift.dart';

import 'connection_io.dart' if (dart.library.html) 'connection_web.dart';

LazyDatabase openConnection() {
  return lazyOpenConnection();
}