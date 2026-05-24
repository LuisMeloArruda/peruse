import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/features/auth/presentation/controller/auth_notifier.dart';
import 'package:peruse/features/profile/domain/entities/user_profile.dart';

part 'profile_notifier.g.dart';

@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  @override
  Future<AppUserProfile?> build() async {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;
    if (user == null) {
      return null;
    }

    final repository = ref.watch(profileRepositoryProvider);
    return repository.ensureCurrentProfile();
  }

  Future<void> updatePreferredLanguage(String preferredLanguage) async {
    final repository = ref.read(profileRepositoryProvider);

    state = await AsyncValue.guard(() async {
      return repository.updatePreferredLanguage(preferredLanguage);
    });
  }

  Future<void> refresh() async {
    final repository = ref.read(profileRepositoryProvider);

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return repository.ensureCurrentProfile();
    });
  }
}