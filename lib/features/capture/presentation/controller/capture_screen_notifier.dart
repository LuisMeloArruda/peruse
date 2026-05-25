import 'dart:async';

import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart'
    as mlkit;

import 'package:peruse/core/llm/models/llm_request.dart';
import 'package:peruse/core/llm/provider/llm_providers.dart';
import 'package:peruse/features/capture/domain/entities/label.dart';
import 'package:peruse/features/capture/presentation/controller/capture_notifier.dart';
import 'package:peruse/features/profile/domain/profile_languages.dart';
import 'package:peruse/features/profile/presentation/controller/profile_notifier.dart';

final captureScreenProvider =
    NotifierProvider.autoDispose<CaptureScreenNotifier, CaptureScreenState>(
      CaptureScreenNotifier.new,
    );

enum CaptureLaunchTarget {
  captureLibrary,
  addWord,
}

class CapturedWordResult {
  const CapturedWordResult({required this.text, required this.imagePath});

  final String text;
  final String imagePath;
}

class CaptureSuggestion {
  const CaptureSuggestion({
    required this.englishText,
    required this.translatedText,
    required this.confidence,
  });

  final String englishText;
  final String translatedText;
  final double confidence;
}

class CaptureReviewData {
  const CaptureReviewData({
    required this.localPath,
    required this.suggestions,
    this.launchTarget = CaptureLaunchTarget.captureLibrary,
  });

  final String localPath;
  final List<CaptureSuggestion> suggestions;
  final CaptureLaunchTarget launchTarget;
}

class CaptureScreenState {
  const CaptureScreenState({
    this.cameraController,
    this.imageLabeler,
    this.availableCameras = const [],
    this.selectedCameraIndex = 0,
    this.initializingCamera = false,
    this.takingPicture = false,
    this.processingImage = false,
    this.lastCapturedPath,
    this.lastDetectedLabels = const [],
    this.cameraError,
  });

  final CameraController? cameraController;
  final mlkit.ImageLabeler? imageLabeler;
  final List<CameraDescription> availableCameras;
  final int selectedCameraIndex;

  final bool initializingCamera;
  final bool takingPicture;
  final bool processingImage;

  final String? lastCapturedPath;
  final List<Label> lastDetectedLabels;
  final String? cameraError;

  CaptureScreenState copyWith({
    CameraController? cameraController,
    mlkit.ImageLabeler? imageLabeler,
    List<CameraDescription>? availableCameras,
    int? selectedCameraIndex,
    bool? initializingCamera,
    bool? takingPicture,
    bool? processingImage,
    String? lastCapturedPath,
    List<Label>? lastDetectedLabels,
    String? cameraError,
  }) {
    return CaptureScreenState(
      cameraController: cameraController ?? this.cameraController,
      imageLabeler: imageLabeler ?? this.imageLabeler,
      availableCameras: availableCameras ?? this.availableCameras,
      selectedCameraIndex: selectedCameraIndex ?? this.selectedCameraIndex,
      initializingCamera: initializingCamera ?? this.initializingCamera,
      takingPicture: takingPicture ?? this.takingPicture,
      processingImage: processingImage ?? this.processingImage,
      lastCapturedPath: lastCapturedPath ?? this.lastCapturedPath,
      lastDetectedLabels: lastDetectedLabels ?? this.lastDetectedLabels,
      cameraError: cameraError ?? this.cameraError,
    );
  }
}

class CaptureScreenNotifier extends Notifier<CaptureScreenState> {
  static const _translationTimeout = Duration(seconds: 8);

  @override
  CaptureScreenState build() {
    ref.onDispose(_disposeResources);
    return const CaptureScreenState();
  }

  Future<void> initializeCamera(
    List<CameraDescription> cameras, {
    int selectedCameraIndex = 0,
  }) async {
    if (state.initializingCamera || cameras.isEmpty) return;

    final resolvedIndex = selectedCameraIndex.clamp(0, cameras.length - 1);

    state = state.copyWith(
      availableCameras: cameras,
      selectedCameraIndex: resolvedIndex,
      initializingCamera: true,
    );

    await _disposeCameraResources();

    final cameraDescription = cameras[resolvedIndex];

    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();

      final labeler = mlkit.ImageLabeler(
        options: mlkit.ImageLabelerOptions(confidenceThreshold: 0.45),
      );

      state = state.copyWith(
        cameraController: controller,
        imageLabeler: labeler,
        cameraError: null,
      );
    } catch (error) {
      await controller.dispose();
      state = state.copyWith(cameraError: error.toString());
    } finally {
      state = state.copyWith(initializingCamera: false);
    }
  }

  Future<void> switchCamera() async {
    final cameras = state.availableCameras;
    if (state.initializingCamera || state.takingPicture || cameras.length < 2) {
      return;
    }

    final nextIndex = (state.selectedCameraIndex + 1) % cameras.length;
    await initializeCamera(cameras, selectedCameraIndex: nextIndex);
  }

  Future<CaptureReviewData?> captureAndAnalyze() async {
    final controller = state.cameraController;
    final imageLabeler = state.imageLabeler;

    if (controller == null ||
        imageLabeler == null ||
        !controller.value.isInitialized ||
        state.takingPicture) {
      return null;
    }

    state = state.copyWith(
      takingPicture: true,
      processingImage: true,
      cameraError: null,
    );

    try {
      final xFile = await controller.takePicture();

      final inputImage = mlkit.InputImage.fromFilePath(xFile.path);

      final labels = await imageLabeler.processImage(inputImage);
      final suggestions = await _buildSuggestions(labels);

      state = state.copyWith(
        lastCapturedPath: xFile.path,
        lastDetectedLabels: [
          for (final suggestion in suggestions)
            Label(
              text: suggestion.englishText,
              confidence: suggestion.confidence,
              language: 'english',
            ),
        ],
      );
      return CaptureReviewData(
        localPath: xFile.path,
        suggestions: suggestions,
      );
    } catch (error) {
      state = state.copyWith(cameraError: error.toString());
      return null;
    } finally {
      state = state.copyWith(takingPicture: false, processingImage: false);
    }
  }

  Future<void> syncAll() async {
    await ref.read(captureControllerProvider.notifier).syncAll();
  }

  Future<void> refreshCaptures() async {
    await ref.read(captureControllerProvider.notifier).refresh();
  }

  Future<List<CaptureSuggestion>> _buildSuggestions(
    List<mlkit.ImageLabel> labels,
  ) async {
    final input = Map<String, double>.fromEntries(
      labels.map((entry) => MapEntry(entry.label, entry.confidence)),
    );
    String preferredLanguageCode = 'en';
    try {
      final profile = await ref.read(profileProvider.future);
      preferredLanguageCode = profile?.preferredLanguage ?? 'en';
    } catch (_) {
      preferredLanguageCode = 'en';
    }
    final targetLanguage = profileLanguageLabel(preferredLanguageCode).toLowerCase();

    final fallbackSuggestions = [
      for (final entry in input.entries)
        CaptureSuggestion(
          englishText: entry.key,
          translatedText: entry.key,
          confidence: entry.value,
        ),
    ];

    if (preferredLanguageCode == 'en') {
      return fallbackSuggestions;
    }

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = connectivity.isNotEmpty &&
          !connectivity.contains(ConnectivityResult.none);
      if (!isOnline) {
        return fallbackSuggestions;
      }

      // try to use cached translations first
      final cache = ref.read(llmTranslationCacheProvider);
      final needed = <String, double>{};
      final results = <String, String>{};

      for (final entry in input.entries) {
        final key = llmCacheKey(targetLanguage, entry.key);
        if (cache.containsKey(key)) {
          results[entry.key] = cache[key]!;
        } else {
          needed[entry.key] = entry.value;
        }
      }

      if (needed.isEmpty) {
        return [
          for (final entry in input.entries)
            CaptureSuggestion(
              englishText: entry.key,
              translatedText: results[entry.key] ?? entry.key,
              confidence: entry.value,
            ),
        ];
      }

      final llmRequest = LlmRequest(
        input: needed,
        sourceLanguage: 'english',
        targetLanguage: targetLanguage,
      );
      final translations = await ref
          .read(llmTranslateProvider(llmRequest).future)
          .timeout(_translationTimeout);

      for (final t in translations.translatedTexts.entries) {
        final key = llmCacheKey(targetLanguage, t.key);
        results[t.key] = t.value;
        ref.read(llmTranslationCacheProvider.notifier).put(key, t.value);
      }

      return [
        for (final entry in input.entries)
          CaptureSuggestion(
            englishText: entry.key,
            translatedText: results[entry.key] ?? entry.key,
            confidence: entry.value,
          ),
      ];
    } on TimeoutException catch (error) {
      debugPrint('Translation timed out, using English labels only: $error');
      return fallbackSuggestions;
    } catch (error) {
      debugPrint('Translation failed, using English labels only: $error');
      return fallbackSuggestions;
    }
  }

  void resetCameraSetup() {
    _disposeResources();
    state = const CaptureScreenState();
  }

  Future<void> _disposeCameraResources() async {
    final controller = state.cameraController;
    if (controller != null) {
      await controller.dispose();
    }
    await state.imageLabeler?.close();
  }

  void _disposeResources() {
    state.cameraController?.dispose();
    state.imageLabeler?.close();
  }
}
