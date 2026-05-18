import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:peruse/core/di/providers.dart';
import 'package:peruse/features/capture/domain/entities/capture.dart';
import 'package:peruse/features/capture/domain/entities/label.dart';
import 'package:peruse/features/capture/domain/repositories/capture_repository.dart';

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

  Future<void> syncAll() async {
    final repository = ref.read(captureRepositoryProvider);

    final previousCaptures =
        state.value ?? <Capture>[];

    state = AsyncData(previousCaptures);

    try {
      await repository.syncPendingCaptures();

      final refreshed =
          await repository.getLocalCaptures();

      state = AsyncData(refreshed);
    } catch (e, st) {
      state = AsyncData(previousCaptures);
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
