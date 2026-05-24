import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
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
import 'package:peruse/features/decks/data/models/deck_model.dart';

part 'deck_repository_impl.g.dart';

class DeckRepositoryImpl implements IDeckRepository {
  final SupabaseClient _supabase;
  final AppDatabase _localDb;
  final FreeDictionaryApi _dictionaryApi;

  DeckRepositoryImpl(this._supabase, this._localDb, this._dictionaryApi);

  @override
  Stream<List<AppDeck>> watchDecks() {
    unawaited(_syncRemoteToLocal());
    unawaited(syncPendingWords());
    return _localDb.decksDao.watchDecks().map((localDecks) {
      return localDecks
          .map((local) => DeckModel.fromDrift(local).toEntity())
          .toList();
    });
  }

  @override
  Future<List<AppDeck>> getDecks() async {
    final localDecks = await _localDb.decksDao.getDecks();
    return localDecks
        .map((local) => DeckModel.fromDrift(local).toEntity())
        .toList();
  }

  @override
  Stream<AppDeck?> watchDeck(String deckId) {
    return _localDb.decksDao.watchDeckById(deckId).map(_mapDeck);
  }

  @override
  Stream<List<AppWord>> watchDeckWords(String deckId) {
    return _localDb.wordsDao
        .watchWordsForDeck(deckId)
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

    final companion = WordDetailsTableCompanion.insert(
      wordId: word.id,
      definition: entry.definition,
      example: entry.example,
      partOfSpeech: entry.partOfSpeech,
      phonetic: entry.phonetic,
      audioUrl: entry.audioUrl,
      rawJson: Value(entry.rawJson),
    );

    await _localDb.wordsDao.upsertWordDetails(companion);
    await _uploadWordDetails(word.id, entry);

    return AppWordDetails(
      wordId: word.id,
      definition: entry.definition,
      example: entry.example,
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
  Future<void> createDeck(AppDeck deck) async {
    final model = DeckModel.fromEntity(deck, isSynced: false);
    await _localDb.decksDao.upsertDeck(model.toCompanion());

    try {
      await _supabase.from('decks').insert(model.toJson());
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
      await _supabase.from('decks').update(model.toJson()).eq('id', deck.id);
      await _localDb.decksDao.updateSyncStatus(deck.id, true);
    } catch (e) {
      debugPrint(
        'Remote update failed. Local changes kept for later retry. Error: $e',
      );
    }
  }

  @override
  Future<void> deleteDeck(String id) async {
    await _localDb.decksDao.deleteDeck(id);

    try {
      await _supabase.from('decks').delete().eq('id', id);
    } catch (e) {
      debugPrint('Remote delete failed. Will retry on next sync. Error: $e');
    }
  }

  Future<void> _syncRemoteToLocal() async {
    try {
      final unsyncedDecks = await _localDb.decksDao.getUnsyncedDecks();

      for (final localDeck in unsyncedDecks) {
        final model = DeckModel.fromDrift(localDeck);
        await _supabase.from('decks').insert(model.toJson());
        await _localDb.decksDao.updateSyncStatus(model.id, true);
      }

      final remoteResponse = await _supabase.from('decks').select();
      final remoteModels = (remoteResponse as List)
          .map((json) => DeckModel.fromJson(json))
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
            synced: const Value(false),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  @override
  Future<void> removeWordFromDeck(String deckId, String wordId) async {
    await (_localDb.delete(
      _localDb.deckWordsTable,
    )..where((t) => t.deckId.equals(deckId) & t.wordId.equals(wordId))).go();
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
          .toList();
      final wordJson = (wordsResponse as List).cast<Map<String, dynamic>>();
      final wordCompanions = wordJson.map(_wordCompanionFromJson).toList();

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

      final remoteImageUrl = await _resolveWordImageUrl(word, userId);
      if (word.imageUrl != null && _isLocalImagePath(word.imageUrl!) && remoteImageUrl == null) {
        return false;
      }

      await _supabase.from('words').upsert({
        'id': word.id,
        'word_text': normalizedText,
        'image_url': remoteImageUrl ?? word.imageUrl,
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

    final extension = p.extension(imageUrl).isEmpty ? '.jpg' : p.extension(imageUrl);
    final storagePath = 'words/$userId/${word.id}$extension';
    await _supabase.storage.from('captures').upload(storagePath, file);
    return _supabase.storage.from('captures').getPublicUrl(storagePath);
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
}

@riverpod
IDeckRepository deckRepository(Ref ref) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  final database = ref.watch(appDatabaseProvider);
  final dictionaryApi = ref.watch(freeDictionaryApiProvider);
  return DeckRepositoryImpl(supabaseClient, database, dictionaryApi);
}
