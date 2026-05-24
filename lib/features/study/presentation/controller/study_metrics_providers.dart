import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peruse/core/di/providers.dart';
import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/features/study/data/models/user_global_stats.dart';

class DailyGoalParams {
  const DailyGoalParams({
    required this.userId,
    required this.date,
    required this.dailyGoalTarget,
  });

  final String userId;
  final DateTime date;
  final int dailyGoalTarget;

  @override
  bool operator ==(Object other) {
    return other is DailyGoalParams &&
        other.userId == userId &&
        other.dailyGoalTarget == dailyGoalTarget &&
        other.date.year == date.year &&
        other.date.month == date.month &&
        other.date.day == date.day;
  }

  @override
  int get hashCode => Object.hash(userId, date.year, date.month, date.day, dailyGoalTarget);
}

final dailyGoalProgressProvider = StreamProvider.family<double, DailyGoalParams>(
  (ref, params) {
    final db = ref.watch(appDatabaseProvider);
    return db.studyDao.watchDailyGoalProgress(
      params.userId,
      params.date,
      params.dailyGoalTarget,
    );
  },
);

final weeklyVelocityProvider = StreamProvider.family<List<LocalDailyProgress>, String>(
  (ref, userId) {
    final db = ref.watch(appDatabaseProvider);
    return db.studyDao.watchWeeklyVelocity(userId);
  },
);

final contributionGridProvider = StreamProvider.family<Map<DateTime, int>, String>(
  (ref, userId) {
    final db = ref.watch(appDatabaseProvider);
    return db.studyDao.watchContributionGrid(userId);
  },
);

final userGlobalStatsProvider = StreamProvider.family<UserGlobalStats, String>(
  (ref, userId) {
    final db = ref.watch(appDatabaseProvider);
    return db.studyDao.watchUserGlobalStats(userId);
  },
);
