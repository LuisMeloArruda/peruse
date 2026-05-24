import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peruse/core/router/router.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/features/capture/presentation/controller/capture_sync_coordinator.dart';
import 'package:peruse/features/flashcards/presentation/controller/flashcard_sync_coordinator.dart';
import 'package:peruse/features/profile/presentation/controller/profile_sync_coordinator.dart';
import 'package:peruse/features/study/presentation/controller/study_sync_coordinator.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(routerProvider);
    ref.watch(captureSyncCoordinatorProvider);
    ref.watch(flashcardSyncCoordinatorProvider);
    ref.watch(profileSyncCoordinatorProvider);
    ref.watch(studySyncCoordinatorProvider);

    return MaterialApp.router(
      routerConfig: goRouter,
      title: 'Peruse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
    );
  }
}
