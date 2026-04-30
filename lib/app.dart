import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peruse/core/router/router.dart';
import 'package:peruse/core/theme/theme.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(routerProvider);

    return MaterialApp.router(
      routerConfig: goRouter,
      title: 'Peruse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
    );
  }
}