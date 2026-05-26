import 'package:drift/drift.dart';
import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/data/local/tables/daily_progress_table.dart';
import 'package:peruse/data/local/tables/study_results_table.dart';
import 'package:peruse/data/local/tables/study_sessions_table.dart';
import 'package:peruse/data/local/tables/user_progress_table.dart';
import 'package:peruse/features/study/data/models/user_global_stats.dart';
import 'package:peruse/features/study/data/models/deck_mastery_stats.dart';

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

  Stream<double> watchDailyGoalProgress(
    String userId,
    DateTime date,
    int dailyGoalTarget,
  ) {
    final dateKey = _formatDateKey(date);
    final query = select(dailyProgressTable)
      ..where((t) => t.userId.equals(userId) & t.date.equals(dateKey));

    return query.watchSingleOrNull().map((row) {
      if (row == null || dailyGoalTarget <= 0) return 0.0;
      final progress = row.wordsStudied / dailyGoalTarget;
      return progress.clamp(0.0, 1.0);
    });
  }

  Stream<List<LocalDailyProgress>> watchWeeklyVelocity(String userId) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final startKey = _formatDateKey(start);
    final endKey = _formatDateKey(now);

    final query = select(dailyProgressTable)
      ..where(
        (t) =>
            t.userId.equals(userId) & t.date.isBetweenValues(startKey, endKey),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.date)]);

    return query.watch();
  }

  Stream<List<LocalDailyProgress>> watchMonthlyVelocity(String userId) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));
    final startKey = _formatDateKey(start);
    final endKey = _formatDateKey(now);

    final query = select(dailyProgressTable)
      ..where(
        (t) =>
            t.userId.equals(userId) & t.date.isBetweenValues(startKey, endKey),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.date)]);

    return query.watch();
  }

  Stream<Map<DateTime, int>> watchContributionGrid(String userId) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 83));
    final startKey = _formatDateKey(start);

    final query = select(dailyProgressTable)
      ..where(
        (t) => t.userId.equals(userId) & t.date.isBiggerOrEqualValue(startKey),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.date)]);

    return query.watch().map((rows) {
      final map = <DateTime, int>{};
      for (final row in rows) {
        final parsed = _parseDateKey(row.date);
        map[parsed] = row.wordsStudied;
      }
      return map;
    });
  }

  Stream<UserGlobalStats> watchUserGlobalStats(String userId) {
    final dateKey = _formatDateKey(DateTime.now());
    final query = select(userProgressTable).join([
      leftOuterJoin(
        dailyProgressTable,
        dailyProgressTable.userId.equalsExp(userProgressTable.userId) &
            dailyProgressTable.date.equals(dateKey),
      ),
    ])..where(userProgressTable.userId.equals(userId));

    return query.watchSingleOrNull().map((row) {
      if (row == null) {
        return UserGlobalStats.empty;
      }

      final progress = row.readTable(userProgressTable);
      final daily = row.readTableOrNull(dailyProgressTable);

      return UserGlobalStats(
        totalWords: progress.totalWordsMastered,
        lifetimeAccuracy: progress.lifetimeAccuracy,
        wordsStudiedToday: daily?.wordsStudied ?? 0,
        currentStreak: progress.currentStreak,
      );
    });
  }

  Stream<DeckMasteryStats> watchDeckMastery({
    required String userId,
    required String deckId,
    int lookbackDays = 30,
    int limit = 50,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: lookbackDays));
    final cutoffMillis = BigInt.from(cutoff.millisecondsSinceEpoch);

    final query =
        select(studyResultsTable).join([
            innerJoin(
              studySessionsTable,
              studySessionsTable.id.equalsExp(studyResultsTable.sessionId),
            ),
          ])
          ..where(
            studySessionsTable.userId.equals(userId) &
                studySessionsTable.deckId.equals(deckId) &
                studySessionsTable.endedAt.isNotNull() &
                studySessionsTable.startedAt.isBiggerOrEqualValue(cutoffMillis),
          )
          ..orderBy([OrderingTerm.desc(studySessionsTable.startedAt)])
          ..limit(limit);

    return query.watch().map((rows) {
      if (rows.isEmpty) return DeckMasteryStats.empty;

      final total = rows.length;
      final correct = rows
          .where((row) => row.readTable(studyResultsTable).isCorrect)
          .length;

      return DeckMasteryStats(
        accuracy: total == 0 ? 0 : correct / total,
        totalAnswers: total,
        correctAnswers: correct,
      );
    });
  }

  Future<void> upsertStudySession(StudySessionsTableCompanion companion) async {
    await into(
      studySessionsTable,
    ).insert(companion, mode: InsertMode.insertOrReplace);
  }

  Future<void> endStudySession(String sessionId, int endedAt) async {
    await (update(
      studySessionsTable,
    )..where((t) => t.id.equals(sessionId))).write(
      StudySessionsTableCompanion(
        endedAt: Value(BigInt.from(endedAt)),
        isSynced: const Value(false),
      ),
    );
  }

  Future<void> insertStudyResult(StudyResultsTableCompanion companion) async {
    await into(
      studyResultsTable,
    ).insert(companion, mode: InsertMode.insertOrReplace);
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
    await into(
      userProgressTable,
    ).insert(companion, mode: InsertMode.insertOrReplace);
  }

  Future<LocalUserProgress?> getUserProgress(String userId) {
    return (select(
      userProgressTable,
    )..where((t) => t.userId.equals(userId))).getSingleOrNull();
  }

  Future<void> upsertDailyProgress(
    DailyProgressTableCompanion companion,
  ) async {
    await into(
      dailyProgressTable,
    ).insert(companion, mode: InsertMode.insertOrReplace);
  }

  Future<LocalDailyProgress?> getDailyProgress(String userId, String date) {
    return (select(dailyProgressTable)
          ..where((t) => t.userId.equals(userId) & t.date.equals(date)))
        .getSingleOrNull();
  }

  Future<List<LocalStudySession>> getUnsyncedSessions() {
    return (select(
      studySessionsTable,
    )..where((t) => t.isSynced.equals(false))).get();
  }

  Future<List<LocalStudyResult>> getUnsyncedResults() {
    return (select(
      studyResultsTable,
    )..where((t) => t.isSynced.equals(false))).get();
  }

  Future<List<LocalUserProgress>> getUnsyncedUserProgress() {
    return (select(
      userProgressTable,
    )..where((t) => t.isSynced.equals(false))).get();
  }

  Future<List<LocalDailyProgress>> getUnsyncedDailyProgress() {
    return (select(
      dailyProgressTable,
    )..where((t) => t.isSynced.equals(false))).get();
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

  Future<void> updateUserProgressSyncStatus(
    String userId,
    bool isSynced,
  ) async {
    await (update(userProgressTable)..where((t) => t.userId.equals(userId)))
        .write(UserProgressTableCompanion(isSynced: Value(isSynced)));
  }

  Future<void> updateDailyProgressSyncStatus(String id, bool isSynced) async {
    await (update(dailyProgressTable)..where((t) => t.id.equals(id))).write(
      DailyProgressTableCompanion(isSynced: Value(isSynced)),
    );
  }

  String _formatDateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime _parseDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
