import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peruse/core/di/providers.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final flashcardSyncCoordinatorProvider = Provider<FlashcardSyncCoordinator>((ref) {
  return FlashcardSyncCoordinator(ref);
});

class FlashcardSyncCoordinator {
  FlashcardSyncCoordinator(this._ref) {
    _ref.listen(connectivityProvider, (previous, next) {
      final wasConnected = _isConnected(previous?.value);
      final nowConnected = _isConnected(next.value);

      if (!wasConnected && nowConnected) {
        _startRetryLoop();
        unawaited(syncSilently());
      }

      if (wasConnected && !nowConnected) {
        _stopRetryLoop();
      }
    });

    Future.microtask(() async {
      final current = await Connectivity().checkConnectivity();
      if (_isConnected(current)) {
        _startRetryLoop();
        await syncSilently();
      }
    });
  }

  final Ref _ref;
  Timer? _retryTimer;
  static const Duration _retryInterval = Duration(seconds: 30);

  Future<void> syncSilently() async {
    await _ref.read(flashcardRepositoryProvider).syncAll();
  }

  bool _isConnected(List<ConnectivityResult>? results) {
    return results != null &&
        results.isNotEmpty &&
        !results.contains(ConnectivityResult.none);
  }

  void _startRetryLoop() {
    _retryTimer ??= Timer.periodic(_retryInterval, (_) {
      unawaited(syncSilently());
    });
  }

  void _stopRetryLoop() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}