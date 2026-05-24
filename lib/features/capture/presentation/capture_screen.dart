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
    final extra = GoRouterState.of(context).extra;
    final launchTarget = extra is CaptureLaunchTarget
        ? extra
        : CaptureLaunchTarget.captureLibrary;

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
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCameraPanel(context, ref, camerasAsync, screenState),
            const Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: _CaptureStatusPill(),
            ),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(child: _CaptureHintCard()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: _CaptureControls(
                takingPicture: screenState.takingPicture,
                onLibraryTap: () => context.go(AppRoutes.captureList),
                onCaptureTap: screenState.takingPicture
                    ? null
                    : () async {
                        final captureData = await screenNotifier
                            .captureAndAnalyze();
                        if (!context.mounted || captureData == null) return;

                        if (launchTarget == CaptureLaunchTarget.addWord) {
                          final selectedWord = await context.push<
                            CapturedWordResult
                          >(
                            AppRoutes.captureResult,
                            extra: CaptureReviewData(
                              localPath: captureData.localPath,
                              suggestions: captureData.suggestions,
                              launchTarget: launchTarget,
                            ),
                          );

                          if (!context.mounted || selectedWord == null) {
                            return;
                          }

                          context.pop(selectedWord);
                          return;
                        }

                        context.push(
                          AppRoutes.captureResult,
                          extra: CaptureReviewData(
                            localPath: captureData.localPath,
                            suggestions: captureData.suggestions,
                            launchTarget: launchTarget,
                          ),
                        );
                      },
                onFlipTap: screenState.takingPicture
                    ? null
                    : () => screenNotifier.switchCamera(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPanel(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<CameraDescription>> camerasAsync,
    CaptureScreenState state,
  ) {
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

    if (state.cameraController == null ||
        !state.cameraController!.value.isInitialized) {
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

   return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Força o preview da câmara a preencher todo o espaço disponível
          Transform.scale(
            scale: 1 / (state.cameraController!.value.aspectRatio * MediaQuery.of(context).size.aspectRatio),
            child: Center(
              child: CameraPreview(state.cameraController!),
            ),
          ),
          // Camada de overlay por cima da câmara
          const _CameraOverlay(),
        ],
      ),
    );


  }
}

class _CaptureStatusPill extends StatelessWidget {
  const _CaptureStatusPill();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60), // adjust this value if needed
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ANALYZING OBJECT',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureHintCard extends StatelessWidget {
  const _CaptureHintCard();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: 150.0,
        ),
        child: _SurfaceCard(
          color: Colors.black.withValues(alpha: 0.5),
          child: Text(
            'Center the text or object within the frame for best results.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _CaptureControls extends StatelessWidget {
  const _CaptureControls({
    required this.takingPicture,
    required this.onLibraryTap,
    required this.onCaptureTap,
    required this.onFlipTap,
  });

  final bool takingPicture;
  final VoidCallback onLibraryTap;
  final VoidCallback? onCaptureTap;
  final VoidCallback? onFlipTap;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.9),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModeLabel(label: 'PHOTO', isActive: true, style: labelStyle),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LibraryButton(onTap: onLibraryTap),
              _ShutterButton(takingPicture: takingPicture, onTap: onCaptureTap),
              _FlipButton(onTap: onFlipTap),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeLabel extends StatelessWidget {
  const _ModeLabel({
    required this.label,
    required this.isActive,
    required this.style,
  });

  final String label;
  final bool isActive;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isActive ? 1 : 0.55,
      child: Text(
        label,
        style: style?.copyWith(
          color: isActive
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _LibraryButton extends StatelessWidget {
  const _LibraryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.photo_library_outlined,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'LIBRARY',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

class _FlipButton extends StatelessWidget {
  const _FlipButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.flip_camera_android_outlined,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'FLIP',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.takingPicture, required this.onTap});

  final bool takingPicture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 90,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: takingPicture
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                )
              : const SizedBox.shrink(),
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
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: child,
    );
  }
}

class _CameraOverlay extends StatelessWidget {
  const _CameraOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _CameraOverlayPainter()));
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
