import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:peruse/core/di/providers.dart';
import 'package:peruse/features/capture/domain/entities/capture.dart';
import 'package:peruse/features/capture/domain/entities/label.dart';

part 'capture_notifier.g.dart';

@riverpod
class CaptureController extends _$CaptureController {
  @override
  Future<List<Capture>> build() async {
    final repository = ref.read(captureRepositoryProvider);
    return repository.getLocalCaptures();
  }

  Future<Capture> saveLocalCapture(
    String localPath,
    List<Label> labels,
  ) async {
    final repository = ref.read(captureRepositoryProvider);

    final capture =
        await repository.saveLocalCapture(localPath, labels);

    final currentCaptures =
        state.value ?? <Capture>[];

    state = AsyncData([capture, ...currentCaptures]);

    return capture;
  }

  Future<bool> syncAll({bool silent = false}) async {
    final repository = ref.read(captureRepositoryProvider);

    final previousCaptures =
        state.value ?? <Capture>[];

    if (!ref.mounted) {
      return false;
    }

    state = AsyncData(previousCaptures);

    try {
      await repository.syncPendingCaptures();

      if (!ref.mounted) {
        return false;
      }

      final refreshed =
          await repository.getLocalCaptures();

      if (!ref.mounted) {
        return false;
      }

      state = AsyncData(refreshed);
      return true;
    } catch (e, st) {
      if (!ref.mounted) {
        return false;
      }

      state = AsyncData(previousCaptures);
      if (!silent) {
        if (!ref.mounted) {
          return false;
        }

        state = AsyncError(e, st);
        rethrow;
      }

      return false;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
