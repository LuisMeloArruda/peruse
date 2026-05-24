import 'package:drift/drift.dart';

import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/data/local/tables/profiles_table.dart';

part 'profiles_dao.g.dart';

@DriftAccessor(tables: [ProfilesTable])
class ProfilesDao extends DatabaseAccessor<AppDatabase> with _$ProfilesDaoMixin {
  ProfilesDao(super.db);

  Stream<LocalProfile?> watchProfileByUserId(String userId) {
    return (select(profilesTable)..where((t) => t.userId.equals(userId)))
        .watchSingleOrNull();
  }

  Future<LocalProfile?> getProfileByUserId(String userId) {
    return (select(profilesTable)..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<void> upsertProfile(ProfilesTableCompanion companion) async {
    await into(profilesTable).insert(
      companion,
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> updateLanguage(String userId, String preferredLanguage) async {
    await (update(profilesTable)..where((t) => t.userId.equals(userId))).write(
      ProfilesTableCompanion(
        preferredLanguage: Value(preferredLanguage),
        isSynced: const Value(false),
        updatedAt: Value(BigInt.from(DateTime.now().millisecondsSinceEpoch)),
      ),
    );
  }

  Future<void> updateSyncStatus(String userId, bool isSynced) async {
    await (update(profilesTable)..where((t) => t.userId.equals(userId))).write(
      ProfilesTableCompanion(isSynced: Value(isSynced)),
    );
  }

  Future<List<LocalProfile>> getUnsyncedProfiles() {
    return (select(profilesTable)..where((t) => t.isSynced.equals(false)))
        .get();
  }
}