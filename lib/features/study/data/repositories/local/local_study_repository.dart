import 'package:drift/drift.dart';

import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/features/study/domain/repositories/study_repository.dart';

class LocalStudyRepository implements IStudyRepository {
  LocalStudyRepository(this._localDb);

  final AppDatabase _localDb;

  @override
  Future<void> completeSession({
    required String sessionId,
    required String userId,
  }) async {
    await _localDb.transaction(() async {
      final results = await (_localDb.select(_localDb.studyResultsTable)
            ..where((t) => t.sessionId.equals(sessionId)))
          .get();

      final totalStudied = results.length;
      final totalCorrect = results.where((row) => row.isCorrect).length;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayKey = _formatDateKey(today);

      final existingDaily = await (_localDb.select(_localDb.dailyProgressTable)
            ..where((t) =>
                t.userId.equals(userId) & t.date.equals(todayKey)))
          .getSingleOrNull();

      if (existingDaily == null) {
        await _localDb.into(_localDb.dailyProgressTable).insert(
              DailyProgressTableCompanion.insert(
                id: '$userId-$todayKey',
                userId: userId,
                date: todayKey,
                wordsStudied: Value(totalStudied),
                correctAnswers: Value(totalCorrect),
                isSynced: const Value(false),
              ),
              mode: InsertMode.insertOrReplace,
            );
      } else {
        await (_localDb.update(_localDb.dailyProgressTable)
              ..where((t) => t.id.equals(existingDaily.id)))
            .write(
          DailyProgressTableCompanion(
            wordsStudied:
                Value(existingDaily.wordsStudied + totalStudied),
            correctAnswers:
                Value(existingDaily.correctAnswers + totalCorrect),
            isSynced: const Value(false),
          ),
        );
      }

      final totalsQuery = _localDb.selectOnly(_localDb.dailyProgressTable)
        ..addColumns([
          _localDb.dailyProgressTable.wordsStudied.sum(),
          _localDb.dailyProgressTable.correctAnswers.sum(),
        ])
        ..where(_localDb.dailyProgressTable.userId.equals(userId));

      final totalsRow = await totalsQuery.getSingle();
      final totalWords =
          totalsRow.read(_localDb.dailyProgressTable.wordsStudied.sum()) ?? 0;
      final totalCorrectAll =
          totalsRow.read(_localDb.dailyProgressTable.correctAnswers.sum()) ?? 0;

        final accuracy = totalWords == 0
          ? 0.0
          : (totalCorrectAll / totalWords);

      final currentProgress =
          await (_localDb.select(_localDb.userProgressTable)
                ..where((t) => t.userId.equals(userId)))
              .getSingleOrNull();

      final nextStreak = _calculateNextStreak(
        currentProgress?.lastStudyDate.toInt(),
        today,
        currentProgress?.currentStreak ?? 0,
      );

      final lastStudyMillis = now.millisecondsSinceEpoch;

      if (currentProgress == null) {
        await _localDb.into(_localDb.userProgressTable).insert(
              UserProgressTableCompanion.insert(
                userId: userId,
                totalWordsMastered: Value(totalWords),
                currentStreak: Value(nextStreak),
                lastStudyDate: Value(BigInt.from(lastStudyMillis)),
                lifetimeAccuracy: Value(accuracy),
                isSynced: const Value(false),
              ),
              mode: InsertMode.insertOrReplace,
            );
      } else {
        await (_localDb.update(_localDb.userProgressTable)
              ..where((t) => t.userId.equals(userId)))
            .write(
          UserProgressTableCompanion(
            totalWordsMastered: Value(totalWords),
            currentStreak: Value(nextStreak),
            lastStudyDate: Value(BigInt.from(lastStudyMillis)),
            lifetimeAccuracy: Value(accuracy),
            isSynced: const Value(false),
          ),
        );
      }
    });
  }

  int _calculateNextStreak(
    int? lastStudyMillis,
    DateTime today,
    int currentStreak,
  ) {
    if (lastStudyMillis == null || lastStudyMillis == 0) return 1;

    final lastDate = DateTime.fromMillisecondsSinceEpoch(lastStudyMillis);
    final lastKey = _formatDateKey(lastDate);
    final todayKey = _formatDateKey(today);

    if (lastKey == todayKey) {
      return currentStreak == 0 ? 1 : currentStreak;
    }

    final yesterdayKey = _formatDateKey(today.subtract(const Duration(days: 1)));
    if (lastKey == yesterdayKey) {
      return currentStreak + 1;
    }

    return 1;
  }

  String _formatDateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
