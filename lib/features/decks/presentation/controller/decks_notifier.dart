import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/features/decks/domain/entities/deck.dart';
import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';

part 'decks_notifier.g.dart';

@riverpod
class DecksNotifier extends _$DecksNotifier {
  @override
  Stream<List<AppDeck>> build() {
    final repository = ref.watch(deckRepositoryProvider);
    return repository.watchDecks();
  }

  Future<void> createDeck({
    required String name,
    String? bio,
    required String color,
    required String icon,
    String? coverImageUrl,
  }) async {
    final authRepository = ref.read(authRepositoryProvider);
    final user = authRepository.currentUser;

    if (user == null) {
      debugPrint('Create deck aborted: no authenticated user.');
      return;
    }

    final deck = AppDeck(
      id: const Uuid().v4(),
      name: name.trim(),
      bio: bio?.trim().isEmpty == true ? null : bio?.trim(),
      userId: user.id,
      color: color,
      icon: icon,
      coverImageUrl: coverImageUrl,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    final repository = ref.read(deckRepositoryProvider);
    await repository.createDeck(deck);
  }

  Future<void> updateDeck({
    required String id,
    required String name,
    String? bio,
    required String color,
    required String icon,
    String? coverImageUrl,
    required int createdAt,
  }) async {
    final authRepository = ref.read(authRepositoryProvider);
    final user = authRepository.currentUser;

    if (user == null) {
      debugPrint('Update deck aborted: no authenticated user.');
      return;
    }

    final deck = AppDeck(
      id: id,
      name: name.trim(),
      bio: bio?.trim().isEmpty == true ? null : bio?.trim(),
      userId: user.id,
      color: color,
      icon: icon,
      coverImageUrl: coverImageUrl,
      createdAt: createdAt,
    );

    final repository = ref.read(deckRepositoryProvider);
    await repository.updateDeck(deck);
  }
}
