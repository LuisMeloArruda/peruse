import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/features/flashcards/data/models/flashcard_model.dart';
import 'package:peruse/features/flashcards/domain/entities/flashcard.dart';
import 'package:peruse/features/flashcards/domain/repositories/flashcard_repository.dart';

class LocalFlashcardRepository implements IFlashcardRepository {
  final AppDatabase _localDb;
  final SupabaseClient _supabase;
  final Uuid _uuid;

  LocalFlashcardRepository(
    this._localDb,
    this._supabase, {
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  @override
  Stream<List<AppFlashcard>> watchDeckFlashcards(String deckId) {
    final cardsStream = _localDb.flashcardsDao.watchFlashcardsForDeck(deckId).map(
      (rows) => rows
          .map((local) => FlashcardModel.fromDrift(local).toEntity())
          .toList(),
    );

    unawaited(syncAll());

    return Stream.fromFuture(_seedFlashcardsFromDeckWords(deckId)).asyncExpand(
      (_) => cardsStream,
    );
  }

  @override
  Future<List<AppFlashcard>> getDeckFlashcards(String deckId) async {
    await _seedFlashcardsFromDeckWords(deckId);
    final rows = await _localDb.flashcardsDao.getFlashcardsForDeck(deckId);
    return rows.map((local) => FlashcardModel.fromDrift(local).toEntity()).toList();
  }

  @override
  Future<void> upsertFlashcard(AppFlashcard flashcard) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final model = FlashcardModel.fromEntity(
      flashcard.copyWith(
        updatedAt: now,
        revision: flashcard.revision + 1,
        isSynced: false,
      ),
      isSynced: false,
    );

    await _localDb.flashcardsDao.upsertFlashcards([model.toCompanion()]);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('Flashcard upload skipped: no authenticated user.');
        return;
      }

      await _supabase.from('flashcards').upsert({
        ...model.toJson(),
        'modified_by': userId,
      });

      await _localDb.flashcardsDao.updateSyncStatus(model.id, true);
    } catch (e) {
      debugPrint('Flashcard sync failed. Local copy kept for retry. Error: $e');
    }
  }

  @override
  Future<void> deleteFlashcard(String flashcardId) async {
    await _localDb.flashcardsDao.softDelete(flashcardId);

    try {
      await _supabase.from('flashcards').upsert({
        'id': flashcardId,
        'is_deleted': true,
      });
    } catch (e) {
      debugPrint('Flashcard delete sync failed. Error: $e');
    }
  }

  @override
  Future<void> syncAll() async {
    await _syncPendingFlashcards();
    await fetchAndCacheUserData();
  }

  @override
  Future<void> fetchAndCacheUserData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Flashcard sync down skipped: no authenticated user.');
      return;
    }

    try {
      final deckIdsResponse = await _supabase
          .from('decks')
          .select('id')
          .eq('user_id', userId);
      final deckIds = (deckIdsResponse as List)
          .map((json) => json['id'] as String)
          .toList();

      if (deckIds.isEmpty) {
        return;
      }

      final flashcardsResponse = await _supabase
          .from('flashcards')
          .select()
          .inFilter('deck_id', deckIds);

      final flashcardCompanions = (flashcardsResponse as List)
          .map((json) => FlashcardModel.fromJson(json as Map<String, dynamic>))
          .map((model) => model.toCompanion(isSyncedOverride: true))
          .toList();

      await _localDb.flashcardsDao.upsertFlashcards(flashcardCompanions);
    } catch (e) {
      debugPrint('Flashcard sync down failed: $e');
    }
  }

  Future<void> _syncPendingFlashcards() async {
    try {
      final pendingRows = await _localDb.flashcardsDao.getUnsyncedFlashcards();
      for (final row in pendingRows) {
        final model = FlashcardModel.fromDrift(row);

        try {
          await _supabase.from('flashcards').upsert(model.toJson());
          await _localDb.flashcardsDao.updateSyncStatus(model.id, true);
        } catch (e) {
          debugPrint('Pending flashcard sync failed: $e');
        }
      }
    } catch (e) {
      debugPrint('Flashcard sync queue failed: $e');
    }
  }

  Future<void> _seedFlashcardsFromDeckWords(String deckId) async {
    try {
      final existingRows = await _localDb.flashcardsDao.getFlashcardsForDeck(deckId);
      final existingWordIds = existingRows.map((row) => row.wordId).toSet();
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return;
      }

      final deckWords = await _localDb.wordsDao
          .watchWordsForDeck(deckId, currentUserId)
          .first;

      if (deckWords.isEmpty) {
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final companions = <FlashcardsTableCompanion>[];

      for (var index = 0; index < deckWords.length; index++) {
        final word = deckWords[index];
        if (existingWordIds.contains(word.id)) {
          continue;
        }

        final details = await _localDb.wordsDao.getWordDetails(word.id);
        companions.add(
          FlashcardsTableCompanion.insert(
            id: _uuid.v4(),
            deckId: deckId,
            wordId: word.id,
            frontText: Value(word.wordText),
            backText: Value(_buildDefaultBackText(word.wordText, details)),
            mediaUrl: Value(word.imageUrl),
            mediaType: Value(word.imageUrl == null || word.imageUrl!.isEmpty ? null : 'image'),
            position: Value(index),
            isDeleted: const Value(false),
            revision: Value(BigInt.from(0)),
            modifiedBy: Value(currentUserId),
            createdAt: BigInt.from(now),
            updatedAt: BigInt.from(now),
            synced: const Value(false),
          ),
        );
      }

      await _localDb.flashcardsDao.upsertFlashcards(companions);
    } catch (e) {
      debugPrint('Flashcard seed failed: $e');
    }
  }

  String? _buildDefaultBackText(String wordText, LocalWordDetails? details) {
    final definition = details?.definition.trim() ?? '';
    final example = details?.example.trim() ?? '';

    if (definition.isNotEmpty && example.isNotEmpty) {
      return '$definition\n\n$example';
    }

    if (definition.isNotEmpty) {
      return definition;
    }

    if (example.isNotEmpty) {
      return example;
    }

    return wordText;
  }
}