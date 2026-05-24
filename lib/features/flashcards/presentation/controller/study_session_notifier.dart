import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/features/study/presentation/controller/study_sync_coordinator.dart';

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
  bool _startInProgress = false;
  bool _endInProgress = false;

  @override
  StudySessionState build() => StudySessionState.initial;

  Future<void> startSession({required String deckId, required String mode}) async {
    if (_startInProgress) return;
    if (state.sessionId != null &&
        state.deckId == deckId &&
        state.mode == mode &&
        !state.isCompleted) {
      return;
    }

    final auth = ref.read(authRepositoryProvider);
    final user = auth.currentUser;
    if (user == null) {
      state = state.copyWith(errorMessage: 'No authenticated user.');
      return;
    }

    _startInProgress = true;
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
    } finally {
      _startInProgress = false;
    }
  }

  Future<void> gradeWord({
    required String wordId,
    required bool correct,
    int? elapsedMillis,
  }) async {
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
    final delta = math.max(elapsedMillis ?? (now - startedAt), 0);
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
    if (sessionId == null || _endInProgress) return;

    final auth = ref.read(authRepositoryProvider);
    final user = auth.currentUser;
    if (user == null) {
      state = state.copyWith(errorMessage: 'No authenticated user.');
      return;
    }

    final endedAt = DateTime.now().millisecondsSinceEpoch;

    _endInProgress = true;

    try {
      final db = ref.read(appDatabaseProvider);
      
      state = state.copyWith(isCompleted: true, wordStartedAt: null);
      
      await db.studyDao.endStudySession(sessionId, endedAt);
      await ref
          .read(studyRepositoryProvider)
          .completeSession(sessionId: sessionId, userId: user.id);
          
      await ref.read(studySyncCoordinatorProvider).syncNow();
    } catch (error) {
      debugPrint('Study session end failed: $error');
      state = state.copyWith(errorMessage: error.toString(), isCompleted: false);
    } finally {
      _endInProgress = false;
    }
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
