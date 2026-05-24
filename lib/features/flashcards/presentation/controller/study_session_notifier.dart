import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/data/local/database/app_database.dart';

part 'study_session_notifier.g.dart';

class StudyResultDraft {
  const StudyResultDraft({
    required this.id,
    required this.wordId,
    required this.isCorrect,
    required this.timeTaken,
  });

  final String id;
  final String wordId;
  final bool isCorrect;
  final int timeTaken;
}

class StudySessionState {
  const StudySessionState({
    required this.deckId,
    required this.mode,
    required this.sessionId,
    required this.wordIds,
    required this.currentIndex,
    required this.correctCount,
    required this.results,
    required this.isLoading,
    required this.isCompleted,
    required this.wordStartedAt,
    this.errorMessage,
  });

  final String? deckId;
  final String? mode;
  final String? sessionId;
  final List<String> wordIds;
  final int currentIndex;
  final int correctCount;
  final List<StudyResultDraft> results;
  final bool isLoading;
  final bool isCompleted;
  final int? wordStartedAt;
  final String? errorMessage;

  String? get currentWordId =>
      currentIndex >= 0 && currentIndex < wordIds.length
          ? wordIds[currentIndex]
          : null;

  int get totalCount => wordIds.length;

  StudySessionState copyWith({
    String? deckId,
    String? mode,
    String? sessionId,
    List<String>? wordIds,
    int? currentIndex,
    int? correctCount,
    List<StudyResultDraft>? results,
    bool? isLoading,
    bool? isCompleted,
    int? wordStartedAt,
    String? errorMessage,
  }) {
    return StudySessionState(
      deckId: deckId ?? this.deckId,
      mode: mode ?? this.mode,
      sessionId: sessionId ?? this.sessionId,
      wordIds: wordIds ?? this.wordIds,
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      wordStartedAt: wordStartedAt ?? this.wordStartedAt,
      errorMessage: errorMessage,
    );
  }

  static const initial = StudySessionState(
    deckId: null,
    mode: null,
    sessionId: null,
    wordIds: [],
    currentIndex: 0,
    correctCount: 0,
    results: [],
    isLoading: false,
    isCompleted: false,
    wordStartedAt: null,
    errorMessage: null,
  );
}

@riverpod
class StudySessionNotifier extends _$StudySessionNotifier {
  final Uuid _uuid = const Uuid();

  @override
  StudySessionState build() => StudySessionState.initial;

  Future<void> startSession({required String deckId, required String mode}) async {
    final auth = ref.read(authRepositoryProvider);
    final user = auth.currentUser;
    if (user == null) {
      state = state.copyWith(errorMessage: 'No authenticated user.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final db = ref.read(appDatabaseProvider);
      final words = await db.wordsDao.watchWordsForDeck(deckId).first;
      final wordIds = words.map((word) => word.id).toList();
      final now = DateTime.now().millisecondsSinceEpoch;
      final sessionId = _uuid.v4();

      await db.studyDao.upsertStudySession(
        StudySessionsTableCompanion.insert(
          id: sessionId,
          userId: user.id,
          deckId: deckId,
          mode: mode,
          startedAt: BigInt.from(now),
          endedAt: const Value(null),
          isSynced: const Value(false),
        ),
      );

      state = state.copyWith(
        deckId: deckId,
        mode: mode,
        sessionId: sessionId,
        wordIds: wordIds,
        currentIndex: 0,
        correctCount: 0,
        results: [],
        isLoading: false,
        isCompleted: wordIds.isEmpty,
        wordStartedAt: wordIds.isEmpty ? null : now,
      );

      if (wordIds.isEmpty) {
        await endSession();
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> gradeWord({required String wordId, required bool correct}) async {
    final sessionId = state.sessionId;
    final deckId = state.deckId;
    if (sessionId == null || deckId == null) return;

    final auth = ref.read(authRepositoryProvider);
    final user = auth.currentUser;
    if (user == null) {
      state = state.copyWith(errorMessage: 'No authenticated user.');
      return;
    }

    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final startedAt = state.wordStartedAt ?? now;
    final delta = math.max(now - startedAt, 0);
    final resultId = _uuid.v4();

    try {
      await db.studyDao.insertStudyResult(
        StudyResultsTableCompanion.insert(
          id: resultId,
          userId: user.id,
          sessionId: sessionId,
          wordId: wordId,
          isCorrect: correct,
          timeTaken: BigInt.from(delta),
          isSynced: const Value(false),
        ),
      );

      await _updateWordConfidence(db, wordId, correct);

      final nextIndex = state.currentIndex + 1;
      final completed = nextIndex >= state.wordIds.length;
      final nextResults = [
        ...state.results,
        StudyResultDraft(
          id: resultId,
          wordId: wordId,
          isCorrect: correct,
          timeTaken: delta,
        ),
      ];

      state = state.copyWith(
        currentIndex: nextIndex,
        correctCount: correct ? state.correctCount + 1 : state.correctCount,
        results: nextResults,
        isCompleted: completed,
        wordStartedAt: completed ? null : now,
      );

      if (completed) {
        await endSession();
      }
    } catch (error) {
      debugPrint('Study grade failed: $error');
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> endSession() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;

    final auth = ref.read(authRepositoryProvider);
    final user = auth.currentUser;
    if (user == null) {
      state = state.copyWith(errorMessage: 'No authenticated user.');
      return;
    }

    final db = ref.read(appDatabaseProvider);
    final endedAt = DateTime.now().millisecondsSinceEpoch;

    try {
      await db.studyDao.endStudySession(sessionId, endedAt);
      await _updateAggregates(db, user.id, endedAt);
      state = state.copyWith(isCompleted: true, wordStartedAt: null);
    } catch (error) {
      debugPrint('Study session end failed: $error');
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> _updateAggregates(
    AppDatabase db,
    String userId,
    int endedAt,
  ) async {
    if (state.results.isEmpty) return;

    final totalStudied = state.results.length;
    final totalCorrect = state.results.where((r) => r.isCorrect).length;

    final current = await db.studyDao.getUserProgress(userId);
    final previousTotal = current?.totalWordsMastered ?? 0;
    final previousAccuracy = current?.lifetimeAccuracy ?? 0;
    final nextTotal = previousTotal + totalStudied;
    final nextAccuracy = nextTotal == 0
        ? 0.0
        : ((previousAccuracy * previousTotal) + totalCorrect) / nextTotal;

    final nextStreak = _calculateNextStreak(
      current?.lastStudyDate.toInt(),
      endedAt,
      current?.currentStreak ?? 0,
    );

    await db.studyDao.upsertUserProgress(
      UserProgressTableCompanion.insert(
        userId: userId,
        totalWordsMastered: Value(nextTotal),
        currentStreak: Value(nextStreak),
        lastStudyDate: Value(BigInt.from(endedAt)),
        lifetimeAccuracy: Value(nextAccuracy),
        isSynced: const Value(false),
      ),
    );

    final dateKey = _formatDateKey(DateTime.fromMillisecondsSinceEpoch(endedAt));
    final existingDaily = await db.studyDao.getDailyProgress(userId, dateKey);
    final dailyId = existingDaily?.id ?? '$userId-$dateKey';

    await db.studyDao.upsertDailyProgress(
      DailyProgressTableCompanion.insert(
        id: dailyId,
        userId: userId,
        date: dateKey,
        wordsStudied:
            Value((existingDaily?.wordsStudied ?? 0) + totalStudied),
        correctAnswers:
            Value((existingDaily?.correctAnswers ?? 0) + totalCorrect),
        isSynced: const Value(false),
      ),
    );
  }

  int _calculateNextStreak(int? lastStudyMillis, int nowMillis, int current) {
    if (lastStudyMillis == null || lastStudyMillis == 0) return 1;

    final lastDate = DateTime.fromMillisecondsSinceEpoch(lastStudyMillis);
    final nowDate = DateTime.fromMillisecondsSinceEpoch(nowMillis);
    final lastKey = _formatDateKey(lastDate);
    final nowKey = _formatDateKey(nowDate);

    if (lastKey == nowKey) return current == 0 ? 1 : current;

    final yesterday = nowDate.subtract(const Duration(days: 1));
    final yesterdayKey = _formatDateKey(yesterday);
    if (lastKey == yesterdayKey) return current + 1;

    return 1;
  }

  String _formatDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _updateWordConfidence(
    AppDatabase db,
    String wordId,
    bool correct,
  ) async {
    final word = await db.wordsDao.getWordById(wordId);
    if (word == null) return;

    final delta = correct ? 0.05 : -0.05;
    final next = (word.confidence + delta).clamp(0.0, 1.0);
    await db.wordsDao.updateWordConfidence(wordId, next);
  }
}
