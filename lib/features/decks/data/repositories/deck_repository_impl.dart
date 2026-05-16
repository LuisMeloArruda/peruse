import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/features/decks/domain/entities/deck.dart';
import 'package:peruse/features/decks/domain/entities/deck_word.dart';
import 'package:peruse/features/decks/domain/repositories/deck_repository.dart';
import 'package:peruse/features/decks/data/models/deck_model.dart';

part 'deck_repository_impl.g.dart';

class DeckRepositoryImpl implements IDeckRepository {
  final SupabaseClient _supabase;
  final AppDatabase _localDb;

  DeckRepositoryImpl(this._supabase, this._localDb);

  @override
  Stream<List<AppDeck>> watchDecks() {
    unawaited(_syncRemoteToLocal());
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
  Future<void> createDeck(AppDeck deck) async {
    final model = DeckModel.fromEntity(deck, isSynced: false);
    await _localDb.decksDao.upsertDeck(model.toCompanion());

    try {
      await _supabase.from('decks').insert(model.toJson());
      await _localDb.decksDao.updateSyncStatus(deck.id, true);
    } catch (e) {
      debugPrint(
        'Deck sync failed. Saved locally for later retry. Error: $e',
      );
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
      debugPrint(
        'Remote delete failed. Will retry on next sync. Error: $e',
      );
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
    throw UnimplementedError();
  }

  @override
  Future<void> removeWordFromDeck(String deckId, String wordId) async {
    throw UnimplementedError();
  }
}

@riverpod
IDeckRepository deckRepository(Ref ref) {
  final supabaseClient = ref.watch(supabaseClientProvider);
  final database = ref.watch(appDatabaseProvider);
  return DeckRepositoryImpl(supabaseClient, database);
}
