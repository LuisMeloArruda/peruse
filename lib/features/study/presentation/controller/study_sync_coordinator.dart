import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peruse/core/di/providers.dart';

final studyConnectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);

final studySyncCoordinatorProvider = Provider<void>((ref) {
  Future<void> syncSilently() async {
    final db = ref.read(appDatabaseProvider);
    final client = ref.read(supabaseClientProvider);

    try {
      final sessions = await db.studyDao.getUnsyncedSessions();
      for (final session in sessions) {
        try {
          await client.from('study_sessions').upsert({
            'id': session.id,
            'user_id': session.userId,
            'deck_id': session.deckId,
            'mode': session.mode,
            'started_at': DateTime.fromMillisecondsSinceEpoch(
              session.startedAt.toInt(),
            ).toIso8601String(),
            'ended_at': session.endedAt == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    session.endedAt!.toInt(),
                  ).toIso8601String(),
            'is_synced': true,
          });
          await db.studyDao.updateSessionSyncStatus(session.id, true);
        } catch (error) {
          debugPrint('Study session sync failed: $error');
        }
      }

      final results = await db.studyDao.getUnsyncedResults();
      for (final result in results) {
        try {
          await client.from('study_results').upsert({
            'id': result.id,
            'user_id': result.userId,
            'session_id': result.sessionId,
            'word_id': result.wordId,
            'is_correct': result.isCorrect,
            'time_taken': result.timeTaken.toInt(),
            'is_synced': true,
          });
          await db.studyDao.updateResultSyncStatus(result.id, true);
        } catch (error) {
          debugPrint('Study result sync failed: $error');
        }
      }

      final userProgress = await db.studyDao.getUnsyncedUserProgress();
      for (final progress in userProgress) {
        try {
          await client.from('user_progress').upsert({
            'user_id': progress.userId,
            'total_words_mastered': progress.totalWordsMastered,
            'current_streak': progress.currentStreak,
            'last_study_date': DateTime.fromMillisecondsSinceEpoch(
              progress.lastStudyDate.toInt(),
            ).toIso8601String(),
            'lifetime_accuracy': progress.lifetimeAccuracy,
            'is_synced': true,
          });
          await db.studyDao.updateUserProgressSyncStatus(progress.userId, true);
        } catch (error) {
          debugPrint('User progress sync failed: $error');
        }
      }

      final dailyProgress = await db.studyDao.getUnsyncedDailyProgress();
      for (final progress in dailyProgress) {
        try {
          await client.from('daily_progress').upsert({
            'id': progress.id,
            'user_id': progress.userId,
            'date': progress.date,
            'words_studied': progress.wordsStudied,
            'correct_answers': progress.correctAnswers,
            'is_synced': true,
          });
          await db.studyDao.updateDailyProgressSyncStatus(progress.id, true);
        } catch (error) {
          debugPrint('Daily progress sync failed: $error');
        }
      }
    } catch (error) {
      debugPrint('Study sync failed: $error');
    }
  }

  bool isConnected(List<ConnectivityResult>? results) {
    return results != null &&
        results.isNotEmpty &&
        !results.contains(ConnectivityResult.none);
  }

  ref.listen(studyConnectivityProvider, (previous, next) {
    final wasConnected = isConnected(previous?.value);
    final nowConnected = isConnected(next.value);

    if (!wasConnected && nowConnected) {
      unawaited(syncSilently());
    }
  });

  Future.microtask(() async {
    final current = await Connectivity().checkConnectivity();
    if (isConnected(current)) {
      await syncSilently();
    }
  });
});
