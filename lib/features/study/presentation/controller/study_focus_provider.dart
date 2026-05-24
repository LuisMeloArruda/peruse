import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';
import 'package:peruse/features/decks/domain/entities/deck.dart';

part 'study_focus_provider.g.dart';

@riverpod
Stream<List<AppDeck>> studyDecks(Ref ref) {
  final repository = ref.watch(deckRepositoryProvider);
  return repository.watchDecks();
}

@Riverpod(keepAlive: true)
class ActiveStudyDeckId extends _$ActiveStudyDeckId {
  @override
  String? build() => null;

  void set(String? deckId) => state = deckId;
}
