import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart' as mlkit;
import 'package:peruse/core/di/providers.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/features/capture/domain/entities/capture.dart';
import 'package:peruse/features/capture/domain/entities/label.dart';
import 'controller/capture_notifier.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  CameraController? _cameraController;
  mlkit.ImageLabeler? _imageLabeler;
  bool _initializingCamera = false;
  bool _takingPicture = false;
  bool _processingImage = false;
  String? _lastCapturedPath;
  List<Label> _lastDetectedLabels = const [];
  String? _cameraError;

  @override
  void dispose() {
    _cameraController?.dispose();
    _imageLabeler?.close();
    super.dispose();
  }

  Future<void> _initializeCamera(List<CameraDescription> cameras) async {
    if (_initializingCamera || _cameraController != null || cameras.isEmpty) {
      return;
    }

    _initializingCamera = true;
    final cameraDescription = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      _imageLabeler = mlkit.ImageLabeler(
        options: mlkit.ImageLabelerOptions(confidenceThreshold: 0.45),
      );
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraError = null;
      });
    } catch (error) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _cameraError = error.toString();
      });
    } finally {
      _initializingCamera = false;
    }
  }

  Future<void> _captureAndAnalyze() async {
    final controller = _cameraController;
    final imageLabeler = _imageLabeler;

    if (controller == null || imageLabeler == null || !controller.value.isInitialized || _takingPicture) {
      return;
    }

    setState(() {
      _takingPicture = true;
      _processingImage = true;
      _cameraError = null;
    });

    try {
      final xFile = await controller.takePicture();
      final inputImage = mlkit.InputImage.fromFilePath(xFile.path);
      final labels = await imageLabeler.processImage(inputImage);

      final detectedLabels = labels
          .map(
            (label) => Label(
              text: label.label,
              confidence: label.confidence,
              language: 'en',
            ),
          )
          .toList();

      await ref.read(captureControllerProvider.notifier).saveLocalCapture(
            xFile.path,
            detectedLabels,
          );

      if (!mounted) return;
      setState(() {
        _lastCapturedPath = xFile.path;
        _lastDetectedLabels = detectedLabels;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = error.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _takingPicture = false;
        _processingImage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final camerasAsync = ref.watch(availableCamerasProvider);
    final capturesAsync = ref.watch(captureControllerProvider);

    camerasAsync.whenData((cameras) {
      if (_cameraController == null && !_initializingCamera) {
        _initializeCamera(cameras);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture & Learn'),
        actions: [
          IconButton(
            onPressed: () => ref.read(captureControllerProvider.notifier).syncAll(),
            icon: const Icon(Icons.sync),
            tooltip: 'Sync pending captures',
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
                child: _buildCameraPanel(camerasAsync),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                flex: 5,
                child: ListView(
                  children: [
                    _buildDetectionCard(),
                    const SizedBox(height: AppSpacing.md),
                    _buildRecentCaptures(capturesAsync),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _takingPicture ? null : _captureAndAnalyze,
        icon: _takingPicture
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.camera_alt),
        label: Text(_takingPicture ? 'Working' : 'Capture'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCameraPanel(AsyncValue<List<CameraDescription>> camerasAsync) {
    if (_cameraError != null) {
      return _SurfaceCard(
        child: Center(
          child: Text(
            'Camera error\n\n$_cameraError',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (camerasAsync.isLoading || _initializingCamera) {
      return const _SurfaceCard(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
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
          CameraPreview(_cameraController!),
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

  Widget _buildDetectionCard() {
    if (_lastDetectedLabels.isEmpty) {
      return const _SurfaceCard(
        child: Text('No detection yet. Capture an object to start.'),
      );
    }

    final primaryLabel = _lastDetectedLabels.first;

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
          if (_lastDetectedLabels.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _lastDetectedLabels
                  .map(
                    (label) => Chip(
                      label: Text('${label.text} ${(label.confidence * 100).toStringAsFixed(0)}%'),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (_lastCapturedPath != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(_lastCapturedPath!),
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          if (_processingImage) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentCaptures(AsyncValue<List<Capture>> capturesAsync) {
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
              capturesAsync.isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: () => ref.read(captureControllerProvider.notifier).refresh(),
                      child: const Text('Refresh'),
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
            error: (error, _) => Text('Could not load captures: $error'),
          ),
        ],
      ),
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile(this.capture);

  final Capture capture;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = capture.labels.isEmpty ? 'No label' : capture.labels.first.text;
    final confidence = capture.labels.isEmpty ? 0.0 : capture.labels.first.confidence;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
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
                ),
                const SizedBox(height: 4),
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}% • ${capture.status}',
                ),
              ],
            ),
          ),
        ],
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
