import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';

final deckConnectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);

final deckSyncCoordinatorProvider = Provider<DeckSyncCoordinator>((ref) {
  return DeckSyncCoordinator(ref);
});

class DeckSyncCoordinator {
  DeckSyncCoordinator(this._ref) {
    _ref.listen(deckConnectivityProvider, (previous, next) {
      final wasConnected = _isConnected(previous?.value);
      final nowConnected = _isConnected(next.value);

      if (!wasConnected && nowConnected) {
        _startRetryLoop();
        unawaited(syncNow());
      }

      if (wasConnected && !nowConnected) {
        _stopRetryLoop();
      }
    });

    Future.microtask(() async {
      final current = await Connectivity().checkConnectivity();
      if (_isConnected(current)) {
        _startRetryLoop();
        await syncNow();
      }
    });
  }

  final Ref _ref;
  bool _isSyncing = false;
  Timer? _retryTimer;
  static const Duration _retryInterval = Duration(seconds: 30);

  Future<void> syncNow() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final repository = _ref.read(deckRepositoryProvider);
      await repository.syncPendingDecks();
      await repository.syncPendingWords();
    } catch (error) {
      debugPrint('Deck sync failed: $error');
      _startRetryLoop();
    } finally {
      _isSyncing = false;
    }
  }

  bool _isConnected(List<ConnectivityResult>? results) {
    return results != null &&
        results.isNotEmpty &&
        !results.contains(ConnectivityResult.none);
  }

  void _startRetryLoop() {
    _retryTimer ??= Timer.periodic(_retryInterval, (_) {
      unawaited(syncNow());
    });
  }

  void _stopRetryLoop() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}
