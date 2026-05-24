import 'package:peruse/features/profile/domain/entities/user_profile.dart';

abstract interface class IProfileRepository {
  Future<AppUserProfile?> getCurrentProfile();
  Future<AppUserProfile> ensureCurrentProfile();
  Future<AppUserProfile> updatePreferredLanguage(String preferredLanguage);
  Future<void> fetchAndCacheUserData();
  Future<void> syncPendingProfile();
}