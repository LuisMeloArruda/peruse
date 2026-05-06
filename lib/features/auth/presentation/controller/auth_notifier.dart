import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:peruse/core/di/providers.dart';
import 'package:peruse/features/auth/domain/entities/app_user.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
Stream<AppUser?> authState(Ref ref) async* {
  final repository = ref.watch(authRepositoryProvider);

  yield repository.currentUser;
  yield* repository.authStateChanges;
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
}