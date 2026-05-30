import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:peruse/core/llm/models/llm_request.dart';
import 'package:peruse/core/llm/provider/llm_providers.dart';
import 'package:peruse/core/llm/services/llm_translation_service.dart';
import 'package:peruse/features/profile/domain/repositories/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/data/remote/dictionary_api/free_dictionary_api.dart';
import 'package:peruse/features/decks/domain/entities/deck.dart';
import 'package:peruse/features/decks/domain/entities/deck_word.dart';
import 'package:peruse/features/decks/domain/entities/word.dart';
import 'package:peruse/features/decks/domain/entities/word_details.dart';
import 'package:peruse/features/decks/domain/repositories/deck_repository.dart';
import 'package:peruse/features/flashcards/data/models/flashcard_model.dart';
import 'package:peruse/features/decks/data/models/deck_model.dart';

part 'deck_repository_impl.g.dart';

class DeckRepositoryImpl implements IDeckRepository {
  final SupabaseClient _supabase;
  final AppDatabase _localDb;
  final FreeDictionaryApi _dictionaryApi;
  final LlmTranslationService _llmTranslationService;
  final IProfileRepository _iProfileRepository;

  DeckRepositoryImpl(
    this._supabase,
    this._localDb,
    this._dictionaryApi,
    this._llmTranslationService,
    this._iProfileRepository,
  );

  @override
  Stream<List<AppDeck>> watchDecks() {
    final userId = _currentUserId();
    if (userId == null) {
      return Stream.value(const []);
    }

    unawaited(_syncRemoteToLocal());
    unawaited(syncPendingDecks());
    unawaited(syncPendingWords());
    return _localDb.decksDao.watchDecks(userId).map((localDecks) {
      return localDecks
          .map((local) => DeckModel.fromDrift(local).toEntity())
          .toList();
    });
  }

  @override
  Future<List<AppDeck>> getDecks() async {
    final userId = _currentUserId();
    if (userId == null) {
      return const [];
    }

    final localDecks = await _localDb.decksDao.getDecks(userId);
    return localDecks
        .map((local) => DeckModel.fromDrift(local).toEntity())
        .toList();
  }

  @override
  Stream<AppDeck?> watchDeck(String deckId) {
    final userId = _currentUserId();
    if (userId == null) {
      return Stream.value(null);
    }

    return _localDb.decksDao.watchDeckById(deckId, userId).map(_mapDeck);
  }

  @override
  Stream<List<AppWord>> watchDeckWords(String deckId) {
    final userId = _currentUserId();
    if (userId == null) {
      return Stream.value(const []);
    }

    unawaited(syncPendingWords());
    return _localDb.wordsDao
        .watchWordsForDeck(deckId, userId)
        .map((words) => words.map(_mapWord).toList());
  }

  @override
  Future<AppWord?> getWordById(String wordId) async {
    final word = await _localDb.wordsDao.getWordById(wordId);
    return word == null ? null : _mapWord(word);
  }

  @override
  Future<AppWordDetails?> getWordDetails(AppWord word) async {
    final cached = await _localDb.wordsDao.getWordDetails(word.id);
    if (cached != null && !_isWordDetailsIncomplete(cached)) {
      return _mapWordDetails(cached);
    }

    final entry = await _dictionaryApi.fetchEntry(word.text);
    if (entry == null) {
      return cached == null ? null : _mapWordDetails(cached);
    }
    final user = await _iProfileRepository.ensureCurrentProfile();
    final textToTranslate = <String, double>{};
    bool hasExample = false;
    if (entry.example.trim().isNotEmpty) {
      textToTranslate[entry.example] = 1.0;
      hasExample = true;
    }

    textToTranslate.addAll({entry.definition: 1.0});

    final request = LlmRequest(
      input: textToTranslate,
      sourceLanguage: 'english',
      targetLanguage: user.preferredLanguage,
    );
    final output = await _llmTranslationService.translate(request);

    final companion = WordDetailsTableCompanion.insert(
      wordId: word.id,
      definition: output.translatedTexts.entries.toList().lastOrNull?.value??'',
      example:  hasExample? output.translatedTexts.entries.toList().firstOrNull?.value ??'':'',
      partOfSpeech: entry.partOfSpeech,
      phonetic: entry.phonetic,
      audioUrl: entry.audioUrl,
      rawJson: Value(entry.rawJson),
    );

    await _localDb.wordsDao.upsertWordDetails(companion);
    await _uploadWordDetails(word.id, entry);

    log(output.translatedTexts.toString(), name: 'getWordDetails');

    return AppWordDetails(
      wordId: word.id,
      definition: output.translatedTexts.entries.toList().lastOrNull?.value??'',
      example:  hasExample? output.translatedTexts.entries.toList().firstOrNull?.value ??'':'',
      partOfSpeech: entry.partOfSpeech,
      phonetic: entry.phonetic,
      audioUrl: entry.audioUrl,
      rawJson: entry.rawJson,
    );
  }

  @override
  Future<void> createWordInDeck({
    required AppWord word,
    required String deckId,
  }) async {
    final normalized = word.text.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Word text is required');
    }

    try {
      await _localDb.transaction(() async {
        await _localDb
            .into(_localDb.wordsTable)
            .insert(
              WordsTableCompanion.insert(
                id: word.id,
                wordText: normalized,
                imageUrl: Value(word.imageUrl),
                confidence: Value(word.confidence),
                sourceScanId: Value(word.sourceScanId),
                createdAt: BigInt.from(word.createdAt),
                synced: const Value(false),
              ),
              mode: InsertMode.insertOrReplace,
            );

        await _localDb
            .into(_localDb.deckWordsTable)
            .insert(
              DeckWordsTableCompanion.insert(
                deckId: deckId,
                wordId: word.id,
                addedAt: BigInt.from(word.createdAt),
                synced: const Value(false),
              ),
              mode: InsertMode.insertOrReplace,
            );
      });

      final wordSynced = await _uploadWord(word, normalized);
      if (wordSynced) {
        await _localDb.wordsDao.updateWordSyncStatus(word.id, true);
      }

      final deckWordSynced = await _uploadDeckWord(
        deckId: deckId,
        wordId: word.id,
        addedAt: word.createdAt,
      );
      if (deckWordSynced) {
        await _localDb.wordsDao.updateDeckWordSyncStatus(deckId, word.id, true);
      }
    } catch (e) {
      debugPrint('Create word failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateWord(AppWord word) async {
    final normalized = word.text.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Word text is required');
    }

    await _localDb.wordsDao.upsertWords([
      WordsTableCompanion.insert(
        id: word.id,
        wordText: normalized,
        imageUrl: Value(word.imageUrl),
        confidence: Value(word.confidence),
        sourceScanId: Value(word.sourceScanId),
        createdAt: BigInt.from(word.createdAt),
        synced: const Value(false),
      ),
    ]);

    try {
      final synced = await _uploadWord(word, normalized);
      final storedWord = await _localDb.wordsDao.getWordById(word.id);
      await _syncFlashcardsForWord(
        wordId: word.id,
        frontText: normalized,
        mediaUrl: storedWord?.imageUrl,
      );
      if (synced) {
        await _localDb.wordsDao.updateWordSyncStatus(word.id, true);
      }
    } catch (e) {
      debugPrint('Word update failed: $e');
    }
  }

  @override
  Future<void> createDeck(AppDeck deck) async {
    final model = DeckModel.fromEntity(deck, isSynced: false);
    await _localDb.decksDao.upsertDeck(model.toCompanion());

    try {
      final coverImageUrl = await _resolveDeckCoverUrl(deck);
      final remoteModel = DeckModel(
        id: deck.id,
        name: deck.name,
        bio: deck.bio,
        userId: deck.userId,
        color: deck.color,
        icon: deck.icon,
        coverImageUrl: coverImageUrl,
        createdAt: deck.createdAt,
        isDeleted: false,
        isSynced: true,
      );

      await _supabase.from('decks').upsert(remoteModel.toJson());
      if (coverImageUrl != null && coverImageUrl != deck.coverImageUrl) {
        await _localDb.decksDao.updateCoverImageUrl(deck.id, coverImageUrl);
      }
      await _localDb.decksDao.updateSyncStatus(deck.id, true);
    } catch (e) {
      debugPrint('Deck sync failed. Saved locally for later retry. Error: $e');
    }
  }

  @override
  Future<void> updateDeck(AppDeck deck) async {
    final model = DeckModel.fromEntity(deck, isSynced: false);
    await _localDb.decksDao.upsertDeck(model.toCompanion());

    try {
      final coverImageUrl = await _resolveDeckCoverUrl(deck);
      final remoteModel = DeckModel(
        id: deck.id,
        name: deck.name,
        bio: deck.bio,
        userId: deck.userId,
        color: deck.color,
        icon: deck.icon,
        coverImageUrl: coverImageUrl,
        createdAt: deck.createdAt,
        isDeleted: false,
        isSynced: true,
      );

      await _supabase.from('decks').upsert(remoteModel.toJson());
      if (coverImageUrl != null && coverImageUrl != deck.coverImageUrl) {
        await _localDb.decksDao.updateCoverImageUrl(deck.id, coverImageUrl);
      }
      await _localDb.decksDao.updateSyncStatus(deck.id, true);
    } catch (e) {
      debugPrint(
        'Remote update failed. Local changes kept for later retry. Error: $e',
      );
    }
  }

  @override
  Future<void> deleteDeck(String id) async {
    await _localDb.decksDao.softDeleteDeck(id);

    try {
      await _supabase.from('decks').delete().eq('id', id);
      await _localDb.decksDao.deleteDeck(id);
    } catch (e) {
      debugPrint('Remote delete failed. Will retry on next sync. Error: $e');
    }
  }

  Future<void> syncPendingDecks() async {
    try {
      final pendingDecks = await _localDb.decksDao.getUnsyncedDecks();
      for (final localDeck in pendingDecks) {
        final model = DeckModel.fromDrift(localDeck);
        if (model.isDeleted) {
          try {
            await _supabase.from('decks').delete().eq('id', model.id);
            await _localDb.decksDao.deleteDeck(model.id);
          } catch (e) {
            debugPrint('Pending deck delete failed: $e');
          }
          continue;
        }

        final deckEntity = model.toEntity();
        final coverImageUrl = await _resolveDeckCoverUrl(deckEntity);
        final remoteModel = DeckModel(
          id: deckEntity.id,
          name: deckEntity.name,
          bio: deckEntity.bio,
          userId: deckEntity.userId,
          color: deckEntity.color,
          icon: deckEntity.icon,
          coverImageUrl: coverImageUrl,
          createdAt: deckEntity.createdAt,
          isDeleted: false,
          isSynced: true,
        );

        await _supabase.from('decks').upsert(remoteModel.toJson());
        if (coverImageUrl != null &&
            coverImageUrl != deckEntity.coverImageUrl) {
          await _localDb.decksDao.updateCoverImageUrl(model.id, coverImageUrl);
        }
        await _localDb.decksDao.updateSyncStatus(model.id, true);
      }
    } catch (e) {
      debugPrint('Pending deck sync failed: $e');
    }
  }

  Future<void> _syncRemoteToLocal() async {
    try {
      final unsyncedDecks = await _localDb.decksDao.getUnsyncedDecks();

      for (final localDeck in unsyncedDecks) {
        final model = DeckModel.fromDrift(localDeck);
        if (model.isDeleted) {
          try {
            await _supabase.from('decks').delete().eq('id', model.id);
            await _localDb.decksDao.deleteDeck(model.id);
          } catch (e) {
            debugPrint('Pending deck delete failed: $e');
          }
          continue;
        }

        final deckEntity = model.toEntity();
        final coverImageUrl = await _resolveDeckCoverUrl(deckEntity);
        final remoteModel = DeckModel(
          id: deckEntity.id,
          name: deckEntity.name,
          bio: deckEntity.bio,
          userId: deckEntity.userId,
          color: deckEntity.color,
          icon: deckEntity.icon,
          coverImageUrl: coverImageUrl,
          createdAt: deckEntity.createdAt,
          isSynced: true,
        );

        await _supabase.from('decks').upsert(remoteModel.toJson());
        if (coverImageUrl != null &&
            coverImageUrl != deckEntity.coverImageUrl) {
          await _localDb.decksDao.updateCoverImageUrl(model.id, coverImageUrl);
        }
        await _localDb.decksDao.updateSyncStatus(model.id, true);
      }

      final remoteResponse = await _supabase.from('decks').select();
      final remoteModels = (remoteResponse as List)
          .map((json) => DeckModel.fromJson(json))
          .where((model) => !model.isDeleted)
          .toList();

      await _localDb.decksDao.upsertDecks(
        remoteModels
            .map((model) => model.toCompanion(isSyncedOverride: true))
            .toList(),
      );
    } catch (e) {
      debugPrint(
        'Sync aborted due to network/auth failure. Offline mode active. Error: $e',
      );
    }
  }

  @override
  Future<void> addWordToDeck(DeckWord deckWord) async {
    await _localDb
        .into(_localDb.deckWordsTable)
        .insert(
          DeckWordsTableCompanion.insert(
            deckId: deckWord.deckId,
            wordId: deckWord.wordId,
            addedAt: BigInt.from(deckWord.addedAt),
            isDeleted: const Value(false),
            synced: const Value(false),
          ),
          mode: InsertMode.insertOrReplace,
        );

    try {
      final ok = await _uploadDeckWord(
        deckId: deckWord.deckId,
        wordId: deckWord.wordId,
        addedAt: deckWord.addedAt,
      );
      if (ok) {
        await _localDb.wordsDao.updateDeckWordSyncStatus(
          deckWord.deckId,
          deckWord.wordId,
          true,
        );
      }
    } catch (e) {
      debugPrint('Deck word upload failed (addWordToDeck): $e');
    }
  }

  @override
  Future<void> removeWordFromDeck(String deckId, String wordId) async {
    await _localDb.wordsDao.markDeckWordDeleted(deckId, wordId);
    await _softDeleteFlashcardsForWord(deckId: deckId, wordId: wordId);

    try {
      await _supabase.from('deck_words').delete().match({
        'deck_id': deckId,
        'word_id': wordId,
      });
      await _localDb.wordsDao.deleteDeckWord(deckId, wordId);
    } catch (e) {
      debugPrint(
        'Remote deck word delete failed. Will retry on next sync. Error: $e',
      );
    }
  }

  @override
  Future<void> syncPendingWords() async {
    try {
      final pendingWords = await _localDb.wordsDao.getUnsyncedWords();
      if (pendingWords.isNotEmpty) {
        debugPrint('Syncing ${pendingWords.length} pending words.');
      }

      for (final localWord in pendingWords) {
        final word = _mapWord(localWord);
        final ok = await _uploadWord(word, word.text);
        if (ok) {
          await _localDb.wordsDao.updateWordSyncStatus(word.id, true);

          final localDetails = await _localDb.wordsDao.getWordDetails(word.id);
          if (localDetails == null || _isWordDetailsIncomplete(localDetails)) {
            await getWordDetails(word);
          }
        }
      }

      final pendingDeckWords = await _localDb.wordsDao.getUnsyncedDeckWords();
      if (pendingDeckWords.isNotEmpty) {
        debugPrint('Syncing ${pendingDeckWords.length} pending deck words.');
      }

      for (final localDeckWord in pendingDeckWords) {
        if (localDeckWord.isDeleted) {
          try {
            await _supabase.from('deck_words').delete().match({
              'deck_id': localDeckWord.deckId,
              'word_id': localDeckWord.wordId,
            });
            await _localDb.wordsDao.deleteDeckWord(
              localDeckWord.deckId,
              localDeckWord.wordId,
            );
          } catch (e) {
            debugPrint('Pending deck word delete failed: $e');
          }
          continue;
        }

        final ok = await _uploadDeckWord(
          deckId: localDeckWord.deckId,
          wordId: localDeckWord.wordId,
          addedAt: localDeckWord.addedAt.toInt(),
        );
        if (ok) {
          await _localDb.wordsDao.updateDeckWordSyncStatus(
            localDeckWord.deckId,
            localDeckWord.wordId,
            true,
          );
        }
      }
    } catch (e) {
      debugPrint('Pending word sync failed: $e');
    }
  }

  @override
  Future<void> fetchAndCacheUserData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Sync down skipped: no authenticated user.');
      return;
    }

    try {
      final pendingDeckIds = (await _localDb.decksDao.getUnsyncedDecks())
          .map((deck) => deck.id)
          .toSet();
      final pendingWordIds = (await _localDb.wordsDao.getUnsyncedWords())
          .map((word) => word.id)
          .toSet();

      final decksResponse = await _supabase
          .from('decks')
          .select()
          .eq('user_id', userId);
      final wordsResponse = await _supabase
          .from('words')
          .select()
          .eq('user_id', userId);

      final deckModels = (decksResponse as List)
          .map(
            (json) => DeckModel.fromJson(
              json as Map<String, dynamic>,
              isSynced: true,
            ),
          )
          .where(
            (model) => !model.isDeleted && !pendingDeckIds.contains(model.id),
          )
          .toList();
      final wordJson = (wordsResponse as List).cast<Map<String, dynamic>>();
      final wordCompanions = wordJson
          .map(_wordCompanionFromJson)
          .where((model) => !pendingWordIds.contains(model.id))
          .toList();

      final deckIds = deckModels.map((deck) => deck.id).toList();
      final wordIds = wordJson.map((json) => json['id'] as String).toList();

      List<Map<String, dynamic>> deckWordsJson = const [];
      if (deckIds.isNotEmpty) {
        deckWordsJson = await _supabase
            .from('deck_words')
            .select()
            .inFilter('deck_id', deckIds);
      }

      List<Map<String, dynamic>> wordDetailsJson = const [];
      if (wordIds.isNotEmpty) {
        wordDetailsJson = await _supabase
            .from('word_details')
            .select()
            .inFilter('word_id', wordIds);
      }

      final deckWordCompanions = deckWordsJson
          .where((json) => json['is_deleted'] != true)
          .map(_deckWordCompanionFromJson)
          .toList();
      final wordDetailsCompanions = wordDetailsJson
          .map(_wordDetailsCompanionFromJson)
          .toList();

      await _localDb.transaction(() async {
        if (deckModels.isNotEmpty) {
          await _localDb.decksDao.upsertDecks(
            deckModels
                .map((model) => model.toCompanion(isSyncedOverride: true))
                .toList(),
          );
        }
        await _localDb.wordsDao.upsertWords(wordCompanions);
        await _localDb.wordsDao.upsertDeckWords(deckWordCompanions);
        await _localDb.wordsDao.upsertWordDetailsList(wordDetailsCompanions);
      });
    } catch (e) {
      debugPrint('Initial sync down failed: $e');
    }
  }

  AppDeck? _mapDeck(LocalDeck? deck) {
    if (deck == null) return null;
    return DeckModel.fromDrift(deck).toEntity();
  }

  String? _currentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  Future<String?> _resolveDeckCoverUrl(AppDeck deck) async {
    final coverImageUrl = deck.coverImageUrl;
    if (coverImageUrl == null || coverImageUrl.isEmpty) {
      return null;
    }

    if (!_isLocalImagePath(coverImageUrl)) {
      return coverImageUrl;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Deck cover upload skipped: no authenticated user.');
      return null;
    }

    final file = File(coverImageUrl);
    if (!await file.exists()) {
      debugPrint(
        'Deck cover upload skipped: local file not found: $coverImageUrl',
      );
      return null;
    }

    final extension = p.extension(coverImageUrl).isEmpty
        ? '.jpg'
        : p.extension(coverImageUrl);
    final storagePath = 'decks/$userId/${deck.id}$extension';
    await _supabase.storage.from('deck-covers').upload(storagePath, file);
    return _supabase.storage.from('deck-covers').getPublicUrl(storagePath);
  }

  AppWord _mapWord(LocalWord word) {
    return AppWord(
      id: word.id,
      text: word.wordText,
      imageUrl: word.imageUrl,
      confidence: word.confidence,
      sourceScanId: word.sourceScanId,
      createdAt: word.createdAt.toInt(),
    );
  }

  AppWordDetails _mapWordDetails(LocalWordDetails details) {
    return AppWordDetails(
      wordId: details.wordId,
      definition: details.definition,
      example: details.example,
      partOfSpeech: details.partOfSpeech,
      phonetic: details.phonetic,
      audioUrl: details.audioUrl,
      rawJson: details.rawJson,
    );
  }

  bool _isWordDetailsIncomplete(LocalWordDetails details) {
    return details.definition.trim().isEmpty ||
        details.partOfSpeech.trim().isEmpty ||
        details.phonetic.trim().isEmpty;
  }

  WordsTableCompanion _wordCompanionFromJson(Map<String, dynamic> json) {
    return WordsTableCompanion.insert(
      id: json['id'] as String,
      wordText: (json['word_text'] as String?) ?? '',
      imageUrl: Value(json['image_url'] as String?),
      confidence: Value(_parseRemoteDouble(json['confidence'])),
      sourceScanId: Value(json['source_scan_id'] as String?),
      createdAt: BigInt.from(_parseRemoteMillis(json['created_at'])),
      synced: const Value(true),
    );
  }

  DeckWordsTableCompanion _deckWordCompanionFromJson(
    Map<String, dynamic> json,
  ) {
    return DeckWordsTableCompanion.insert(
      deckId: json['deck_id'] as String,
      wordId: json['word_id'] as String,
      addedAt: BigInt.from(_parseRemoteMillis(json['added_at'])),
      isDeleted: Value(json['is_deleted'] == true),
      synced: const Value(true),
    );
  }

  WordDetailsTableCompanion _wordDetailsCompanionFromJson(
    Map<String, dynamic> json,
  ) {
    final rawJson = _encodeRawJson(json['raw_json']);

    return WordDetailsTableCompanion.insert(
      wordId: json['word_id'] as String,
      definition: (json['definition'] as String?) ?? '',
      example: (json['example'] as String?) ?? '',
      partOfSpeech: (json['part_of_speech'] as String?) ?? '',
      phonetic: (json['phonetic'] as String?) ?? '',
      audioUrl: (json['audio_url'] as String?) ?? '',
      rawJson: Value(rawJson),
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

  double _parseRemoteDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String? _encodeRawJson(dynamic rawJson) {
    if (rawJson == null) return null;
    if (rawJson is String) return rawJson;
    return jsonEncode(rawJson);
  }

  Future<bool> _uploadWord(AppWord word, String normalizedText) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('Word upload skipped: no authenticated user.');
        return false;
      }

      String? remoteImageUrl;
      try {
        remoteImageUrl = await _resolveWordImageUrl(word, userId);
      } catch (e) {
        debugPrint('Word image upload skipped: $e');
        remoteImageUrl =
            word.imageUrl != null && !_isLocalImagePath(word.imageUrl!)
            ? word.imageUrl
            : null;
      }

      await _supabase.from('words').upsert({
        'id': word.id,
        'word_text': normalizedText,
        'image_url':
            remoteImageUrl ??
            (word.imageUrl != null && !_isLocalImagePath(word.imageUrl!)
                ? word.imageUrl
                : null),
        'confidence': word.confidence,
        'source_scan_id': word.sourceScanId,
        'user_id': userId,
        'created_at': DateTime.fromMillisecondsSinceEpoch(
          word.createdAt,
        ).toIso8601String(),
      });

      if (remoteImageUrl != null && remoteImageUrl != word.imageUrl) {
        await _localDb.wordsDao.updateWordImageUrl(word.id, remoteImageUrl);
      }

      return true;
    } catch (e) {
      debugPrint('Word upload failed: $e');
      return false;
    }
  }

  Future<String?> _resolveWordImageUrl(AppWord word, String userId) async {
    final imageUrl = word.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }

    if (!_isLocalImagePath(imageUrl)) {
      return imageUrl;
    }

    final file = File(imageUrl);
    if (!await file.exists()) {
      debugPrint('Word image upload skipped: local file not found: $imageUrl');
      return null;
    }

    final extension = p.extension(imageUrl).isEmpty
        ? '.jpg'
        : p.extension(imageUrl);
    final storagePath = 'words/$userId/${word.id}$extension';
    await _supabase.storage.from('words').upload(storagePath, file);
    return _supabase.storage.from('words').getPublicUrl(storagePath);
  }

  bool _isLocalImagePath(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return true;
    return !uri.hasScheme || uri.scheme == 'file';
  }

  Future<bool> _uploadDeckWord({
    required String deckId,
    required String wordId,
    required int addedAt,
  }) async {
    try {
      await _supabase.from('deck_words').upsert({
        'deck_id': deckId,
        'word_id': wordId,
        'added_at': DateTime.fromMillisecondsSinceEpoch(
          addedAt,
        ).toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Deck word upload failed: $e');
      return false;
    }
  }

  Future<void> _uploadWordDetails(String wordId, DictionaryEntry entry) async {
    try {
      dynamic rawJson;
      try {
        rawJson = jsonDecode(entry.rawJson);
      } catch (_) {
        rawJson = null;
      }

      await _supabase.from('word_details').upsert({
        'word_id': wordId,
        'definition': entry.definition,
        'example': entry.example,
        'part_of_speech': entry.partOfSpeech,
        'phonetic': entry.phonetic,
        'audio_url': entry.audioUrl,
        'raw_json': rawJson,
      });
    } catch (e) {
      debugPrint('Word details upload failed: $e');
    }
  }

  Future<String?> _syncFlashcardsForWord({
    required String wordId,
    required String frontText,
    required String? mediaUrl,
  }) async {
    final flashcards = await _localDb.flashcardsDao.getFlashcardsByWordId(
      wordId,
    );
    if (flashcards.isEmpty) {
      return null;
    }

    final userId = _supabase.auth.currentUser?.id;
    final now = DateTime.now().millisecondsSinceEpoch;
    String? latestMediaUrl;

    for (final local in flashcards) {
      final model = FlashcardModel.fromDrift(local);
      final updatedMediaUrl = mediaUrl ?? model.mediaUrl;
      final updatedModel = FlashcardModel(
        id: model.id,
        deckId: model.deckId,
        wordId: model.wordId,
        frontText: frontText,
        backText: model.backText,
        mediaUrl: updatedMediaUrl,
        mediaType: updatedMediaUrl == null || updatedMediaUrl.isEmpty
            ? null
            : 'image',
        position: model.position,
        isDeleted: model.isDeleted,
        revision: model.revision + 1,
        modifiedBy: userId ?? model.modifiedBy,
        createdAt: model.createdAt,
        updatedAt: now,
        isSynced: false,
      );

      await _localDb.flashcardsDao.upsertFlashcards([
        updatedModel.toCompanion(isSyncedOverride: false),
      ]);

      latestMediaUrl = updatedMediaUrl;

      try {
        if (userId == null) {
          continue;
        }

        await _supabase.from('flashcards').upsert({
          ...updatedModel.toJson(),
          'modified_by': userId,
        });
        await _localDb.flashcardsDao.updateSyncStatus(updatedModel.id, true);
      } catch (e) {
        debugPrint('Flashcard sync after word update failed: $e');
      }
    }

    return latestMediaUrl;
  }

  Future<void> _softDeleteFlashcardsForWord({
    required String deckId,
    required String wordId,
  }) async {
    final flashcards = await _localDb.flashcardsDao.getFlashcardsForDeckAndWord(
      deckId,
      wordId,
    );
    if (flashcards.isEmpty) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final local in flashcards) {
      final model = FlashcardModel.fromDrift(local);
      final deletedModel = FlashcardModel(
        id: model.id,
        deckId: model.deckId,
        wordId: model.wordId,
        frontText: model.frontText,
        backText: model.backText,
        mediaUrl: model.mediaUrl,
        mediaType: model.mediaType,
        position: model.position,
        isDeleted: true,
        revision: model.revision + 1,
        modifiedBy: model.modifiedBy,
        createdAt: model.createdAt,
        updatedAt: now,
        isSynced: false,
      );

      await _localDb.flashcardsDao.upsertFlashcards([
        deletedModel.toCompanion(isSyncedOverride: false),
      ]);

      try {
        await _supabase.from('flashcards').upsert({
          'id': deletedModel.id,
          'is_deleted': true,
        });
        await _localDb.flashcardsDao.updateSyncStatus(deletedModel.id, true);
      } catch (e) {
        debugPrint('Flashcard delete sync failed: $e');
      }
    }
  }
}

@riverpod
IDeckRepository deckRepository(Ref ref) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  final database = ref.watch(appDatabaseProvider);
  final dictionaryApi = ref.watch(freeDictionaryApiProvider);
  final translationService = ref.watch(llmTranslationServiceProvider);
  return DeckRepositoryImpl(
    supabaseClient,
    database,
    dictionaryApi,
    translationService,
    ref.watch(profileRepositoryProvider),
  );
}
