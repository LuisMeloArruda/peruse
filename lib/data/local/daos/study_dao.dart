import 'package:drift/drift.dart';
import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/data/local/tables/daily_progress_table.dart';
import 'package:peruse/data/local/tables/study_results_table.dart';
import 'package:peruse/data/local/tables/study_sessions_table.dart';
import 'package:peruse/data/local/tables/user_progress_table.dart';

part 'study_dao.g.dart';

@DriftAccessor(
  tables: [
    StudySessionsTable,
    StudyResultsTable,
    UserProgressTable,
    DailyProgressTable,
  ],
)
class StudyDao extends DatabaseAccessor<AppDatabase> with _$StudyDaoMixin {
  StudyDao(super.db);

  Future<void> upsertStudySession(StudySessionsTableCompanion companion) async {
    await into(studySessionsTable).insert(
      companion,
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> endStudySession(String sessionId, int endedAt) async {
    await (update(studySessionsTable)..where((t) => t.id.equals(sessionId)))
        .write(
      StudySessionsTableCompanion(
        endedAt: Value(BigInt.from(endedAt)),
        isSynced: const Value(false),
      ),
    );
  }

  Future<void> insertStudyResult(StudyResultsTableCompanion companion) async {
    await into(studyResultsTable).insert(
      companion,
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> insertStudyResults(
    List<StudyResultsTableCompanion> companions,
  ) async {
    if (companions.isEmpty) return;

    await batch((batch) {
      batch.insertAll(
        studyResultsTable,
        companions,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<void> upsertUserProgress(UserProgressTableCompanion companion) async {
    await into(userProgressTable).insert(
      companion,
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<LocalUserProgress?> getUserProgress(String userId) {
    return (select(userProgressTable)..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<void> upsertDailyProgress(DailyProgressTableCompanion companion) async {
    await into(dailyProgressTable).insert(
      companion,
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<LocalDailyProgress?> getDailyProgress(
    String userId,
    String date,
  ) {
    return (select(dailyProgressTable)
          ..where((t) => t.userId.equals(userId) & t.date.equals(date)))
        .getSingleOrNull();
  }

  Future<List<LocalStudySession>> getUnsyncedSessions() {
    return (select(studySessionsTable)..where((t) => t.isSynced.equals(false)))
        .get();
  }

  Future<List<LocalStudyResult>> getUnsyncedResults() {
    return (select(studyResultsTable)..where((t) => t.isSynced.equals(false)))
        .get();
  }

  Future<List<LocalUserProgress>> getUnsyncedUserProgress() {
    return (select(userProgressTable)..where((t) => t.isSynced.equals(false)))
        .get();
  }

  Future<List<LocalDailyProgress>> getUnsyncedDailyProgress() {
    return (select(dailyProgressTable)..where((t) => t.isSynced.equals(false)))
        .get();
  }

  Future<void> updateSessionSyncStatus(String id, bool isSynced) async {
    await (update(studySessionsTable)..where((t) => t.id.equals(id))).write(
      StudySessionsTableCompanion(isSynced: Value(isSynced)),
    );
  }

  Future<void> updateResultSyncStatus(String id, bool isSynced) async {
    await (update(studyResultsTable)..where((t) => t.id.equals(id))).write(
      StudyResultsTableCompanion(isSynced: Value(isSynced)),
    );
  }

  Future<void> updateUserProgressSyncStatus(String userId, bool isSynced) async {
    await (update(userProgressTable)..where((t) => t.userId.equals(userId)))
        .write(
      UserProgressTableCompanion(isSynced: Value(isSynced)),
    );
  }

  Future<void> updateDailyProgressSyncStatus(String id, bool isSynced) async {
    await (update(dailyProgressTable)..where((t) => t.id.equals(id))).write(
      DailyProgressTableCompanion(isSynced: Value(isSynced)),
    );
  }
}
