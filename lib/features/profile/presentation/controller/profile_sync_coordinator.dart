import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peruse/core/di/providers.dart';

final profileConnectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);

final profileSyncCoordinatorProvider = Provider<ProfileSyncCoordinator>((ref) {
  final coordinator = ProfileSyncCoordinator(ref);
  return coordinator;
});

class ProfileSyncCoordinator {
  ProfileSyncCoordinator(this._ref) {
    _ref.listen(profileConnectivityProvider, (previous, next) {
      final wasConnected = _isConnected(previous?.value);
      final nowConnected = _isConnected(next.value);

      if (!wasConnected && nowConnected) {
        unawaited(syncNow());
      }
    });

    Future.microtask(() async {
      final current = await Connectivity().checkConnectivity();
      if (_isConnected(current)) {
        unawaited(syncNow());
      }
    });
  }

  final Ref _ref;
  bool _isSyncing = false;

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final repository = _ref.read(profileRepositoryProvider);
      await repository.syncPendingProfile();
    } catch (error) {
      debugPrint('Profile sync failed: $error');
    } finally {
      _isSyncing = false;
    }
  }

  bool _isConnected(List<ConnectivityResult>? result) {
    if (result == null || result.isEmpty) {
      return false;
    }

    return result.any((item) => item != ConnectivityResult.none);
  }
}
