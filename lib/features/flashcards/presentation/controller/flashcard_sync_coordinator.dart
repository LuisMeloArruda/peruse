import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peruse/core/di/providers.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final flashcardSyncCoordinatorProvider = Provider<void>((ref) {
  Future<void> syncSilently() async {
    await ref.read(flashcardRepositoryProvider).syncAll();
  }

  bool isConnected(List<ConnectivityResult>? results) {
    return results != null &&
        results.isNotEmpty &&
        !results.contains(ConnectivityResult.none);
  }

  ref.listen(connectivityProvider, (previous, next) {
    final wasConnected = isConnected(previous?.value);
    final nowConnected = isConnected(next.value);

    if (!wasConnected && nowConnected) {
      unawaited(syncSilently());
    }
  });

  Future.microtask(() async {
    final current = await Connectivity().checkConnectivity();
    if (isConnected(current)) {
      await syncSilently();
    }
  });
});