import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/data/local/database/app_database.dart';

final studyConnectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);

final studySyncCoordinatorProvider = Provider<StudySyncCoordinator>((ref) {
  final coordinator = StudySyncCoordinator(ref);
  return coordinator;
});

class StudySyncCoordinator {
  StudySyncCoordinator(this._ref) {
    _ref.listen(studyConnectivityProvider, (previous, next) {
      final wasConnected = _isConnected(previous?.value);
      final nowConnected = _isConnected(next.value);

      if (!wasConnected && nowConnected) {
        _startRetryLoop();
        unawaited(syncNow());
      }

      if (wasConnected && !nowConnected) {
        _stopRetryLoop();
      }
    });

    Future.microtask(() async {
      final user = _ref.read(authRepositoryProvider).currentUser;
      final current = await Connectivity().checkConnectivity();
      if (user != null && _isConnected(current)) {
        unawaited(hydrateFromRemote(user.id));
      }

      if (_isConnected(current)) {
        _startRetryLoop();
        await syncNow();
      }
    });
  }

  final Ref _ref;
  bool _isSyncing = false;
  bool _isHydrating = false;
  Timer? _retryTimer;
  static const Duration _retryInterval = Duration(seconds: 30);

  Future<void> hydrateFromRemote(String userId) async {
    if (_isHydrating) return;
    _isHydrating = true;

    final db = _ref.read(appDatabaseProvider);
    final client = _ref.read(supabaseClientProvider);

    try {
      final sessionsResponse = await client
          .from('study_sessions')
          .select()
          .eq('user_id', userId);
      final resultsResponse = await client
          .from('study_results')
          .select()
          .eq('user_id', userId);
      final dailyResponse = await client
          .from('daily_progress')
          .select()
          .eq('user_id', userId);
      final progressResponse = await client
          .from('user_progress')
          .select()
          .eq('user_id', userId);

      final sessionRows = (sessionsResponse as List)
          .cast<Map<String, dynamic>>();
      final resultRows = (resultsResponse as List).cast<Map<String, dynamic>>();
      final dailyRows = (dailyResponse as List).cast<Map<String, dynamic>>();
      final progressRows = (progressResponse as List)
          .cast<Map<String, dynamic>>();

      final sessionCompanions = sessionRows
          .map(_sessionCompanionFromJson)
          .toList();
      final resultCompanions = resultRows
          .map(_resultCompanionFromJson)
          .toList();
      final dailyCompanions = dailyRows.map(_dailyCompanionFromJson).toList();
      final progressCompanions = progressRows
          .map(_progressCompanionFromJson)
          .toList();

      await db.transaction(() async {
        if (sessionCompanions.isNotEmpty) {
          await db.batch((batch) {
            batch.insertAll(
              db.studySessionsTable,
              sessionCompanions,
              mode: InsertMode.insertOrReplace,
            );
          });
        }

        if (resultCompanions.isNotEmpty) {
          await db.batch((batch) {
            batch.insertAll(
              db.studyResultsTable,
              resultCompanions,
              mode: InsertMode.insertOrReplace,
            );
          });
        }

        if (dailyCompanions.isNotEmpty) {
          await db.batch((batch) {
            batch.insertAll(
              db.dailyProgressTable,
              dailyCompanions,
              mode: InsertMode.insertOrReplace,
            );
          });
        }

        if (progressCompanions.isNotEmpty) {
          await db.batch((batch) {
            batch.insertAll(
              db.userProgressTable,
              progressCompanions,
              mode: InsertMode.insertOrReplace,
            );
          });
        }
      });
    } catch (error) {
      debugPrint('Study hydration failed: $error');
    } finally {
      _isHydrating = false;
    }
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;

    final db = _ref.read(appDatabaseProvider);
    final client = _ref.read(supabaseClientProvider);

    try {
      var hadError = false;

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
          hadError = true;
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
          hadError = true;
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
          hadError = true;
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
          hadError = true;
          debugPrint('Daily progress sync failed: $error');
        }
      }

      if (hadError) {
        _startRetryLoop();
      }
    } catch (error) {
      debugPrint('Study sync failed: $error');
      _startRetryLoop();
    } finally {
      _isSyncing = false;
    }
  }

  bool _isConnected(List<ConnectivityResult>? results) {
    return results != null &&
        results.isNotEmpty &&
        !results.contains(ConnectivityResult.none);
  }

  void _startRetryLoop() {
    _retryTimer ??= Timer.periodic(_retryInterval, (_) {
      unawaited(syncNow());
    });
  }

  void _stopRetryLoop() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  StudySessionsTableCompanion _sessionCompanionFromJson(
    Map<String, dynamic> json,
  ) {
    return StudySessionsTableCompanion.insert(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      deckId: json['deck_id'] as String,
      mode: (json['mode'] as String?) ?? 'flashcards',
      startedAt: BigInt.from(_parseRemoteMillis(json['started_at'])),
      endedAt: Value(_parseNullableMillis(json['ended_at'])),
      isSynced: const Value(true),
    );
  }

  StudyResultsTableCompanion _resultCompanionFromJson(
    Map<String, dynamic> json,
  ) {
    return StudyResultsTableCompanion.insert(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sessionId: json['session_id'] as String,
      wordId: json['word_id'] as String,
      isCorrect: (json['is_correct'] as bool?) ?? false,
      timeTaken: BigInt.from(_parseRemoteInt(json['time_taken'])),
      isSynced: const Value(true),
    );
  }

  DailyProgressTableCompanion _dailyCompanionFromJson(
    Map<String, dynamic> json,
  ) {
    return DailyProgressTableCompanion.insert(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: (json['date'] as String?) ?? '',
      wordsStudied: Value(_parseRemoteInt(json['words_studied'])),
      correctAnswers: Value(_parseRemoteInt(json['correct_answers'])),
      isSynced: const Value(true),
    );
  }

  UserProgressTableCompanion _progressCompanionFromJson(
    Map<String, dynamic> json,
  ) {
    return UserProgressTableCompanion.insert(
      userId: json['user_id'] as String,
      totalWordsMastered: Value(_parseRemoteInt(json['total_words_mastered'])),
      currentStreak: Value(_parseRemoteInt(json['current_streak'])),
      lastStudyDate: Value(
        BigInt.from(_parseRemoteMillis(json['last_study_date'])),
      ),
      lifetimeAccuracy: Value(_parseRemoteDouble(json['lifetime_accuracy'])),
      isSynced: const Value(true),
    );
  }

  int _parseRemoteMillis(dynamic value) {
    if (value is int) return value;
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value).millisecondsSinceEpoch;
      } catch (_) {
        return 0;
      }
    }
    return 0;
  }

  int _parseRemoteInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _parseRemoteDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  BigInt? _parseNullableMillis(dynamic value) {
    if (value == null) return null;
    return BigInt.from(_parseRemoteMillis(value));
  }
}
