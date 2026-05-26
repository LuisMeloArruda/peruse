import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peruse/core/localization/locale_ext.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/features/flashcards/presentation/controller/study_session_notifier.dart';

class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(BuildContext context, WidgetRef ref, int index) {
    final location = GoRouterState.of(context).uri.toString();
    final leavingDeckStudy =
        navigationShell.currentIndex == 0 && index != 0 && location.contains('/study');

    if (leavingDeckStudy) {
      ref.read(studySessionProvider.notifier).endSession();
    }

    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBarTheme(
        data: const NavigationBarThemeData(
          indicatorColor: AppColors.navSelectedBg,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
        child: NavigationBar(
          height: 72,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) =>
              _onDestinationSelected(context, ref, index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.view_agenda_outlined),
              selectedIcon: const Icon(Icons.view_agenda),
              label: context.translate('nav_decks'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.school_outlined),
              selectedIcon: const Icon(Icons.school),
              label: context.translate('nav_study'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights),
              label: context.translate('nav_growth'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: context.translate('nav_profile'),
            ),
          ],
        ),
      ),
    );
  }
}
