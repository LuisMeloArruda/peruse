import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peruse/core/di/providers.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/features/capture/domain/entities/capture.dart';
import 'controller/capture_notifier.dart';
import 'controller/capture_screen_notifier.dart';

class CaptureScreen extends ConsumerWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camerasAsync = ref.watch(availableCamerasProvider);
    final capturesAsync = ref.watch(captureControllerProvider);
    final screenState = ref.watch(captureScreenProvider);
    final screenNotifier = ref.read(captureScreenProvider.notifier);

    camerasAsync.whenData((cameras) {
      if (screenState.cameraController == null && !screenState.initializingCamera) {
        screenNotifier.initializeCamera(cameras);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture & Learn'),
        actions: [
          capturesAsync.when(
            data: (_) => IconButton(
              onPressed: () async {
                try {
                  await screenNotifier.syncAll();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sync completed successfully'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sync failed: $error'),
                      duration: const Duration(seconds: 4),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.sync),
              tooltip: 'Sync pending captures',
            ),
            loading: () => Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            error: (error, _) => Tooltip(
              message: 'Sync error: ${error.toString()}',
              child: IconButton(
                onPressed: () async {
                  try {
                    await screenNotifier.syncAll();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sync completed successfully'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sync failed: $error'),
                        duration: const Duration(seconds: 4),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.sync_problem, color: Colors.red),
                tooltip: 'Retry sync',
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: _buildCameraPanel(context, camerasAsync, screenState),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                flex: 5,
                child: ListView(
                  children: [
                    _buildDetectionCard(context, screenState),
                    const SizedBox(height: AppSpacing.md),
                    _buildRecentCaptures(context, capturesAsync, ref),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: screenState.takingPicture ? null : screenNotifier.captureAndAnalyze,
        icon: screenState.takingPicture
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.camera_alt),
        label: Text(screenState.takingPicture ? 'Working' : 'Capture'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCameraPanel(BuildContext context, AsyncValue<List<CameraDescription>> camerasAsync, CaptureScreenState state) {
    if (state.cameraError != null) {
      return _SurfaceCard(
        child: Center(
          child: Text(
            'Camera error\n\n${state.cameraError}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (camerasAsync.isLoading || state.initializingCamera) {
      return const _SurfaceCard(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.cameraController == null || !state.cameraController!.value.isInitialized) {
      return _SurfaceCard(
        child: Center(
          child: Text(
            camerasAsync.hasError
                ? 'Unable to load cameras: ${camerasAsync.error}'
                : 'No camera available',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(state.cameraController!),
          const _CameraOverlay(),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _SurfaceCard(
              color: Colors.black.withValues(alpha: 0.45),
              child: Text(
                'Point at an object and capture it to see the English label and confidence.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionCard(BuildContext context, CaptureScreenState state) {
    if (state.lastDetectedLabels.isEmpty) {
      return const _SurfaceCard(
        child: Text('No detection yet. Capture an object to start.'),
      );
    }

    final primaryLabel = state.lastDetectedLabels.first;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detected object',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Text(
            primaryLabel.text,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Confidence ${(primaryLabel.confidence * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (state.lastDetectedLabels.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.lastDetectedLabels
                  .map(
                    (label) => Chip(
                      label: Text('${label.text} ${(label.confidence * 100).toStringAsFixed(0)}%'),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (state.lastCapturedPath != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(state.lastCapturedPath!),
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (state.processingImage) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentCaptures(BuildContext context, AsyncValue<List<Capture>> capturesAsync, WidgetRef ref) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent captures',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              capturesAsync.when(
                data: (_) => TextButton(
                  onPressed: () => ref.read(captureControllerProvider.notifier).refresh(),
                  child: const Text('Refresh'),
                ),
                loading: () => const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (error, _) => Tooltip(
                  message: 'Error: ${error.toString()}',
                  child: IconButton(
                    onPressed: () => ref.read(captureControllerProvider.notifier).refresh(),
                    icon: const Icon(Icons.error_outline, color: Colors.red),
                    tooltip: 'Retry',
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          capturesAsync.when(
            data: (captures) {
              if (captures.isEmpty) {
                return const Text('Nothing saved locally yet.');
              }

              return Column(
                children: captures.take(5).map(_CaptureTile.new).toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Failed to load captures',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.red),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile(this.capture);

  final Capture capture;

  Color _getStatusColor(String status) {
    return switch (status) {
      'uploaded' => Colors.green,
      'uploading' => Colors.blue,
      'failed' => Colors.red,
      _ => Colors.orange, // pending
    };
  }

  IconData _getStatusIcon(String status) {
    return switch (status) {
      'uploaded' => Icons.cloud_done_outlined,
      'uploading' => Icons.cloud_upload_outlined,
      'failed' => Icons.error_outline,
      _ => Icons.schedule_outlined, // pending
    };
  }

  @override
  Widget build(BuildContext context) {
    final primaryLabel = capture.labels.isEmpty ? 'No label' : capture.labels.first.text;
    final confidence = capture.labels.isEmpty ? 0.0 : capture.labels.first.confidence;
    final statusColor = _getStatusColor(capture.status);
    final statusIcon = _getStatusIcon(capture.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: statusColor.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
              child: const Icon(Icons.image_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    primaryLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(confidence * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Tooltip(
                message: 'Status: ${capture.status}',
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}

class _CameraOverlay extends StatelessWidget {
  const _CameraOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _CameraOverlayPainter(),
      ),
    );
  }
}

class _CameraOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;

    const horizontalMargin = 36.0;
    final frameRect = Rect.fromLTWH(
      horizontalMargin,
      size.height * 0.18,
      size.width - horizontalMargin * 2,
      size.height * 0.44,
    );

    canvas.drawRect(Offset.zero & size, overlayPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(28)),
      framePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
