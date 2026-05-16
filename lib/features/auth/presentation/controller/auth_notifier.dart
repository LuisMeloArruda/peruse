import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:peruse/core/di/providers.dart';
import 'package:peruse/features/auth/domain/entities/app_user.dart';
import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
Stream<AppUser?> authState(Ref ref) async* {
  final repository = ref.watch(authRepositoryProvider);
  final database = ref.watch(appDatabaseProvider);
  final deckRepository = ref.read(deckRepositoryProvider);

  final current = repository.currentUser;
  if (current == null) {
    await database.clearUserData();
  } else {
    unawaited(deckRepository.fetchAndCacheUserData());
  }
  yield current;

  await for (final user in repository.authStateChanges) {
    if (user == null) {
      await database.clearUserData();
    } else {
      unawaited(deckRepository.fetchAndCacheUserData());
    }
    yield user;
  }
}

@riverpod
class AuthController extends _$AuthController {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final loginUseCase = ref.read(loginUseCaseProvider);
      await loginUseCase(email, password);
    });
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      await repository.signOut();
    });
  }

  Future<void> register(String email, String password) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final registerUseCase = ref.read(registerUseCaseProvider);
      await registerUseCase(email, password);
    });
  }

  Future<void> loginWithGoogle() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      await repository.signInWithGoogle();
    });
  }
}