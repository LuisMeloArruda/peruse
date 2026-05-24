import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peruse/core/di/providers.dart';
import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';
import 'package:peruse/features/decks/domain/entities/word.dart';
import 'package:peruse/features/study/data/models/user_global_stats.dart';
import 'package:peruse/features/study/data/models/deck_mastery_stats.dart';

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

class DeckMasteryParams {
  const DeckMasteryParams({
    required this.userId,
    required this.deckId,
    this.lookbackDays = 30,
    this.limit = 50,
  });

  final String userId;
  final String deckId;
  final int lookbackDays;
  final int limit;

  @override
  bool operator ==(Object other) {
    return other is DeckMasteryParams &&
        other.userId == userId &&
        other.deckId == deckId &&
        other.lookbackDays == lookbackDays &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(userId, deckId, lookbackDays, limit);
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

final monthlyVelocityProvider = StreamProvider.family<List<LocalDailyProgress>, String>(
  (ref, userId) {
    final db = ref.watch(appDatabaseProvider);
    return db.studyDao.watchMonthlyVelocity(userId);
  },
);

final deckWordsProvider = StreamProvider.family<List<AppWord>, String>(
  (ref, deckId) {
    final repository = ref.watch(deckRepositoryProvider);
    return repository.watchDeckWords(deckId);
  },
);

final deckWordCountProvider = StreamProvider.family<int, String>(
  (ref, deckId) {
    final repository = ref.watch(deckRepositoryProvider);
    return repository.watchDeckWords(deckId).map((words) => words.length);
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

final deckMasteryProvider = StreamProvider.family<DeckMasteryStats, DeckMasteryParams>(
  (ref, params) {
    final db = ref.watch(appDatabaseProvider);
    return db.studyDao.watchDeckMastery(
      userId: params.userId,
      deckId: params.deckId,
      lookbackDays: params.lookbackDays,
      limit: params.limit,
    );
  },
);
