import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/di/providers.dart';
import '../../../domain/entities/app_user.dart';

part 'auth_notifier.g.dart';

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  FutureOr<AppUser?> build() {
    final repository = ref.watch(authRepositoryProvider);
    return repository.currentUser;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final loginUseCase = ref.read(loginUseCaseProvider);
      return await loginUseCase(email, password);
    });
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      await repository.signOut();
      return null;
    });
  }

  Future<void> register(String email, String password) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final registerUseCase = ref.read(registerUseCaseProvider);
      return await registerUseCase(email, password);
    });
  }
}