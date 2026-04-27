import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'presentation/features/auth/login_screen.dart';
import 'presentation/features/auth/auth_notifier.dart';
import 'presentation/features/auth/register_screen.dart';

part 'app.g.dart';

@riverpod
GoRouter router(Ref ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final isLogedIn = authState.value != null;
      
      final isAuthPage = state.matchedLocation == '/login' || 
                         state.matchedLocation == '/register';

      if (!isLogedIn && !isAuthPage) return '/login';
      
      if (isLogedIn && isAuthPage) return '/';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Home Page')),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
    ],
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(routerProvider);

    return MaterialApp.router(
      routerConfig: goRouter,
      title: 'Peruse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }
}