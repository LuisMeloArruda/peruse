import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/features/flashcards/domain/entities/flashcard.dart';

part 'flashcard_notifier.g.dart';

class FlashcardStudyState {
  const FlashcardStudyState({
    required this.flashcards,
    required this.completedCount,
    required this.isFlipped,
    required this.isBusy,
    required this.isLoading,
    this.errorMessage,
  });

  final List<AppFlashcard> flashcards;
  final int completedCount;
  final bool isFlipped;
  final bool isBusy;
  final bool isLoading;
  final String? errorMessage;

  AppFlashcard? get currentCard => flashcards.isEmpty ? null : flashcards.first;

  int get totalCount => flashcards.length + completedCount;

  FlashcardStudyState copyWith({
    List<AppFlashcard>? flashcards,
    int? completedCount,
    bool? isFlipped,
    bool? isBusy,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FlashcardStudyState(
      flashcards: flashcards ?? this.flashcards,
      completedCount: completedCount ?? this.completedCount,
      isFlipped: isFlipped ?? this.isFlipped,
      isBusy: isBusy ?? this.isBusy,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  static const initial = FlashcardStudyState(
    flashcards: [],
    completedCount: 0,
    isFlipped: false,
    isBusy: false,
    isLoading: true,
    errorMessage: null,
  );
}

@riverpod
class FlashcardStudyNotifier extends _$FlashcardStudyNotifier {
  StreamSubscription<List<AppFlashcard>>? _subscription;

  @override
  FlashcardStudyState build(String deckId) {
    final repository = ref.watch(flashcardRepositoryProvider);

    _subscription = repository.watchDeckFlashcards(deckId).listen(
      (cards) {
        final mergedQueue = _mergeQueue(state.flashcards, cards);
        state = state.copyWith(
          flashcards: mergedQueue,
          isFlipped: false,
          isLoading: false,
          errorMessage: null,
        );
      },
      onError: (error, stackTrace) {
        state = state.copyWith(isLoading: false, errorMessage: error.toString());
      },
    );

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return FlashcardStudyState.initial;
  }

  void toggleFlip() {
    if (state.currentCard == null) return;
    state = state.copyWith(isFlipped: !state.isFlipped);
  }

  Future<void> markGotIt() async {
    final currentCard = state.currentCard;
    if (currentCard == null) return;

    final nextQueue = [...state.flashcards]..removeAt(0);
    state = state.copyWith(flashcards: nextQueue, completedCount: state.completedCount + 1, isFlipped: false);

    await _persistCard(currentCard);
  }

  Future<void> markTryAgain() async {
    final currentCard = state.currentCard;
    if (currentCard == null) return;

    final nextQueue = [...state.flashcards]..removeAt(0)..add(currentCard);
    state = state.copyWith(flashcards: nextQueue, isFlipped: false);

    await _persistCard(currentCard);
  }

  Future<void> updateCurrentCard({
    String? frontText,
    String? backText,
  }) async {
    final currentCard = state.currentCard;
    if (currentCard == null) return;

    final updatedCard = currentCard.copyWith(
      frontText: frontText,
      backText: backText,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      revision: currentCard.revision + 1,
      isSynced: false,
    );

    state = state.copyWith(
      flashcards: [updatedCard, ...state.flashcards.skip(1)],
      isFlipped: false,
      isBusy: true,
    );

    try {
      await ref.read(flashcardRepositoryProvider).upsertFlashcard(updatedCard);
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isBusy: false);
      }
    }
  }

  Future<bool> syncAll({bool silent = false}) async {
    final repository = ref.read(flashcardRepositoryProvider);
    final previousState = state;

    if (!ref.mounted) {
      return false;
    }

    state = state.copyWith(isBusy: true);

    try {
      await repository.syncAll();
      if (!ref.mounted) {
        return false;
      }

      state = state.copyWith(isBusy: false, errorMessage: null);
      return true;
    } catch (error) {
      if (!ref.mounted) {
        return false;
      }

      state = previousState.copyWith(isBusy: false);
      if (!silent) {
        state = state.copyWith(errorMessage: error.toString());
        rethrow;
      }

      return false;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  Future<void> _persistCard(AppFlashcard card) async {
    final repository = ref.read(flashcardRepositoryProvider);
    await repository.upsertFlashcard(card);
  }

  List<AppFlashcard> _mergeQueue(
    List<AppFlashcard> currentQueue,
    List<AppFlashcard> latestQueue,
  ) {
    if (currentQueue.isEmpty) {
      return latestQueue;
    }

    final latestById = {
      for (final card in latestQueue) card.id: card,
    };
    final merged = <AppFlashcard>[];

    for (final card in currentQueue) {
      final updated = latestById.remove(card.id);
      if (updated != null) {
        merged.add(updated);
      }
    }

    merged.addAll(latestById.values);
    return merged;
  }
}