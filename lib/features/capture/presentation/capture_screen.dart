import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peruse/core/di/providers.dart';
import 'package:peruse/core/router/routes.dart';
import 'package:peruse/core/theme/theme.dart';
import 'controller/capture_screen_notifier.dart';

class CaptureScreen extends ConsumerWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camerasAsync = ref.watch(availableCamerasProvider);
    final screenState = ref.watch(captureScreenProvider);
    final screenNotifier = ref.read(captureScreenProvider.notifier);

    camerasAsync.whenData((cameras) {
      if (screenState.cameraController == null &&
          !screenState.initializingCamera &&
          screenState.cameraError == null &&
          cameras.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (screenState.cameraController == null &&
              !screenState.initializingCamera &&
              screenState.cameraError == null) {
            screenNotifier.initializeCamera(cameras);
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture'),
        actions: [
          IconButton(
            onPressed: () => context.go(AppRoutes.captureList),
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Capture list',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: _buildCameraPanel(context, ref, camerasAsync, screenState),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: screenState.takingPicture
            ? null
            : () async {
                final reviewData = await screenNotifier.captureAndAnalyze();
                if (!context.mounted || reviewData == null) return;
                context.push(AppRoutes.captureReview, extra: reviewData);
              },
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

  Widget _buildCameraPanel(BuildContext context, WidgetRef ref, AsyncValue<List<CameraDescription>> camerasAsync, CaptureScreenState state) {
    if (state.cameraError != null) {
      return _SurfaceCard(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Camera error\n\n${state.cameraError}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(availableCamerasProvider);
                  ref.read(captureScreenProvider.notifier).resetCameraSetup();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry camera'),
              ),
            ],
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                camerasAsync.hasError
                    ? 'Unable to load cameras: ${camerasAsync.error}'
                    : 'No camera available',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(availableCamerasProvider);
                  ref.read(captureScreenProvider.notifier).resetCameraSetup();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry camera'),
              ),
            ],
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
                'Point at an object and capture it to review the photo first.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
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
