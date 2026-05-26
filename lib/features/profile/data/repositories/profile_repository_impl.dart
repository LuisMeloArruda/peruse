import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/features/profile/data/models/user_profile_model.dart';
import 'package:peruse/features/profile/domain/entities/user_profile.dart';
import 'package:peruse/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements IProfileRepository {
  ProfileRepositoryImpl(this._client, this._localDb);

  final SupabaseClient _client;
  final AppDatabase _localDb;

  @override
  Future<AppUserProfile?> getCurrentProfile() async {
    final userId = _currentUserId();
    if (userId == null) {
      return null;
    }

    final localProfile = await _localDb.profilesDao.getProfileByUserId(userId);
    return localProfile == null
        ? null
        : UserProfileModel.fromDrift(localProfile).toEntity();
  }

  @override
  Future<AppUserProfile> ensureCurrentProfile() async {
    final userId = _currentUserId();
    if (userId == null) {
      throw StateError('Cannot load profile without an authenticated user.');
    }

    final localProfile = await _localDb.profilesDao.getProfileByUserId(userId);
    if (localProfile != null) {
      return UserProfileModel.fromDrift(localProfile).toEntity();
    }

    await fetchAndCacheUserData();

    final hydrated = await _localDb.profilesDao.getProfileByUserId(userId);
    if (hydrated != null) {
      return UserProfileModel.fromDrift(hydrated).toEntity();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final fallback = UserProfileModel(
      userId: userId,
      preferredLanguage: 'en',
      createdAt: now,
      updatedAt: now,
      isSynced: false,
    );

    await _localDb.profilesDao.upsertProfile(fallback.toCompanion());
    await _upsertRemote(fallback);
    await _localDb.profilesDao.updateSyncStatus(userId, true);

    return fallback.toEntity();
  }

  @override
  Future<AppUserProfile> updatePreferredLanguage(
    String preferredLanguage,
  ) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw StateError('Cannot update profile without an authenticated user.');
    }

    final existing = await _localDb.profilesDao.getProfileByUserId(userId);
    final now = DateTime.now().millisecondsSinceEpoch;

    final model = UserProfileModel(
      userId: userId,
      preferredLanguage: preferredLanguage,
      createdAt: existing?.createdAt.toInt() ?? now,
      updatedAt: now,
      isSynced: false,
    );

    await _localDb.profilesDao.upsertProfile(model.toCompanion());

    try {
      await _upsertRemote(model);
      await _localDb.profilesDao.updateSyncStatus(userId, true);
    } catch (error) {
      debugPrint('Profile update sync failed: $error');
    }

    final savedProfile = await _localDb.profilesDao.getProfileByUserId(userId);
    return (savedProfile == null
            ? model
            : UserProfileModel.fromDrift(savedProfile))
        .toEntity();
  }

  @override
  Future<void> fetchAndCacheUserData() async {
    final userId = _currentUserId();
    if (userId == null) {
      return;
    }

    try {
      final remoteResponse = await _client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (remoteResponse == null) {
        final localProfile = await _localDb.profilesDao.getProfileByUserId(
          userId,
        );
        final fallback = localProfile == null
            ? UserProfileModel(
                userId: userId,
                preferredLanguage: 'en',
                createdAt: DateTime.now().millisecondsSinceEpoch,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
                isSynced: false,
              )
            : UserProfileModel.fromDrift(localProfile);

        await _localDb.profilesDao.upsertProfile(fallback.toCompanion());
        await _upsertRemote(fallback);
        await _localDb.profilesDao.updateSyncStatus(userId, true);
        return;
      }

      final remoteProfile = UserProfileModel.fromJson(
        Map<String, dynamic>.from(remoteResponse),
      );
      await _localDb.profilesDao.upsertProfile(
        remoteProfile.toCompanion(isSyncedOverride: true),
      );
    } catch (error) {
      debugPrint('Profile hydration failed: $error');
    }
  }

  @override
  Future<void> syncPendingProfile() async {
    final pendingProfiles = await _localDb.profilesDao.getUnsyncedProfiles();
    for (final localProfile in pendingProfiles) {
      try {
        final model = UserProfileModel.fromDrift(localProfile);
        await _upsertRemote(model);
        await _localDb.profilesDao.updateSyncStatus(localProfile.userId, true);
      } catch (error) {
        debugPrint('Profile sync failed: $error');
      }
    }
  }

  Future<void> _upsertRemote(UserProfileModel profile) async {
    await _client.from('profiles').upsert(profile.toJson());
  }

  String? _currentUserId() {
    return _client.auth.currentUser?.id;
  }
}
