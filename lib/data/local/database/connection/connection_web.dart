import 'package:drift/drift.dart';
import 'package:drift/web.dart';

LazyDatabase lazyOpenConnection() {
  return LazyDatabase(() async => WebDatabase('peruse'));
}