import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:peruse/core/router/routes.dart';
import 'package:peruse/features/auth/presentation/controller/auth_notifier.dart';
import 'package:peruse/features/auth/presentation/login_screen.dart';
import 'package:peruse/features/auth/presentation/register_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@riverpod
GoRouter router(Ref ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final isLogedIn = authState.value != null;

      final isAuthPage = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      if (!isLogedIn && !isAuthPage) return AppRoutes.login;

      if (isLogedIn && isAuthPage) return AppRoutes.home;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home Page')),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
    ],
  );
}