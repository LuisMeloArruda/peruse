import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localization_agent/flutter_localization_agent.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peruse/core/di/providers.dart';
import 'package:peruse/core/localization/app_base_translations.dart';
import 'package:peruse/core/localization/supported_languages.dart';
import 'package:peruse/core/presentation/splash_screen.dart';
import 'package:peruse/core/router/router.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/features/capture/presentation/controller/capture_sync_coordinator.dart';
import 'package:peruse/features/flashcards/presentation/controller/flashcard_sync_coordinator.dart';
import 'package:peruse/features/profile/presentation/controller/profile_notifier.dart';
import 'package:peruse/features/profile/presentation/controller/profile_sync_coordinator.dart';
import 'package:peruse/features/study/presentation/controller/study_sync_coordinator.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translation = ref.watch(translationServiceProvider);
    final theme = AppTheme.light();

    if (!translation.hasValue) {
      return MaterialApp(
        title: appBaseTranslations['app_title']!,
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: SplashScreen(
          error: translation.hasError ? translation.error : null,
          onRetry: translation.hasError
              ? () => ref.invalidate(translationServiceProvider)
              : null,
        ),
      );
    }

    return const _PeruseApp();
  }
}

class _PeruseApp extends ConsumerWidget {
  const _PeruseApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(routerProvider);
    final translationService = ref
        .watch(translationServiceProvider)
        .requireValue;

    ref.watch(profileProvider).whenData((profile) {
      if (profile == null) return;

      final target = appSupportedLanguages.firstWhere(
        (language) => language.code == profile.preferredLanguage,
        orElse: () => appInitialLanguage,
      );

      if (translationService.currentLanguage.code != target.code) {
        unawaited(translationService.changeLanguage(target));
      }
    });

    ref.watch(captureSyncCoordinatorProvider);
    ref.watch(flashcardSyncCoordinatorProvider);
    ref.watch(profileSyncCoordinatorProvider);
    ref.watch(studySyncCoordinatorProvider);

    return ListenableBuilder(
      listenable: translationService,
      builder: (context, _) {
        return MaterialApp.router(
          locale: translationService.currentLanguage.toLocale(),
          supportedLocales: translationService.supportedLocales,
          localizationsDelegates: [
            TranslationLocalizationsDelegate(translationService),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: goRouter,
          title: translationService.getTranslation('app_title'),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
        );
      },
    );
  }
}
