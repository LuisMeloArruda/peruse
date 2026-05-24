import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:peruse/core/router/routes.dart';
import 'package:peruse/features/auth/presentation/controller/auth_notifier.dart';
import 'package:peruse/features/auth/presentation/login_screen.dart';
import 'package:peruse/features/auth/presentation/register_screen.dart';
import 'package:peruse/features/decks/presentation/add_deck_screen.dart';
import 'package:peruse/features/decks/presentation/add_word_screen.dart';
import 'package:peruse/features/decks/presentation/deck_detail_screen.dart';
import 'package:peruse/features/decks/presentation/decks_screen.dart';
import 'package:peruse/features/decks/presentation/study_session_screen.dart';
import 'package:peruse/features/decks/presentation/word_detail_screen.dart';
import 'package:peruse/features/capture/domain/entities/capture.dart';
import 'package:peruse/features/capture/presentation/capture_screen.dart';
import 'package:peruse/features/capture/presentation/capture_list_screen.dart';
import 'package:peruse/features/capture/presentation/capture_result_screen.dart';
import 'package:peruse/features/capture/presentation/capture_detail_screen.dart';
import 'package:peruse/features/capture/presentation/controller/capture_screen_notifier.dart';
import 'package:peruse/features/profile/presentation/profile_screen.dart';
import 'package:peruse/features/study/presentation/growth_screen.dart';
import 'package:peruse/features/study/presentation/study_hub_screen.dart';
import 'package:peruse/core/widgets/main_shell_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

final RouteObserver<PageRoute<dynamic>> appRouteObserver =
  RouteObserver<PageRoute<dynamic>>();

@riverpod
GoRouter router(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.decks,
    observers: [appRouteObserver],
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final isLoggedIn = authState.value != null;

      final isAuthPage =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      if (!isLoggedIn && !isAuthPage) return AppRoutes.login;

      if (isLoggedIn && isAuthPage) return AppRoutes.decks;

      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.decks,
                builder: (context, state) => const DecksScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => const AddDeckScreen(),
                  ),
                  GoRoute(
                    path: ':deckId',
                    builder: (context, state) {
                      final deckId = state.pathParameters['deckId'];
                      if (deckId == null || deckId.isEmpty) {
                        return const DecksScreen();
                      }
                      return DeckDetailScreen(deckId: deckId);
                    },
                    routes: [
                      GoRoute(
                        path: 'study',
                        builder: (context, state) {
                          final deckId = state.pathParameters['deckId'];
                          if (deckId == null || deckId.isEmpty) {
                            return const DecksScreen();
                          }
                          return StudySessionScreen(deckId: deckId);
                        },
                      ),
                      GoRoute(
                        path: 'add-word',
                        builder: (context, state) {
                          final deckId = state.pathParameters['deckId'];
                          if (deckId == null || deckId.isEmpty) {
                            return const DecksScreen();
                          }
                          return AddWordScreen(deckId: deckId);
                        },
                      ),
                      GoRoute(
                        path: 'words/:wordId',
                        builder: (context, state) {
                          final wordId = state.pathParameters['wordId'];
                          if (wordId == null || wordId.isEmpty) {
                            return const DecksScreen();
                          }
                          return WordDetailScreen(wordId: wordId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.study,
                builder: (context, state) => const StudyHubScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.growth,
                builder: (context, state) => const GrowthScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.capture,
                builder: (context, state) => const CaptureScreen(),
              ),
              GoRoute(
                path: AppRoutes.captureList,
                builder: (context, state) => const CaptureListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.captureResult,
        builder: (context, state) {
          final capture = state.extra;
          if (capture is CaptureReviewData) {
            return CaptureResultScreen(reviewData: capture);
          }

          return const Scaffold(
            body: Center(child: Text('No capture data available.')),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.captureDetail,
        builder: (context, state) {
          final cap = state.extra;
          if (cap is Capture) {
            return CaptureDetailScreen(capture: cap);
          }

          return const Scaffold(
            body: Center(child: Text('No capture data available.')),
          );
        },
      ),
    ],
  );
}
