import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.view_agenda_outlined),
              selectedIcon: Icon(Icons.view_agenda),
              label: 'Decks',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Study',
            ),
            NavigationDestination(
              icon: _CaptureIcon(isSelected: false),
              selectedIcon: _CaptureIcon(isSelected: true),
              label: 'Capture',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureIcon extends StatelessWidget {
  const _CaptureIcon({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final background = isSelected
        ? AppColors.primary
        : AppColors.surfaceContainer;
    final foreground = isSelected ? AppColors.onPrimary : AppColors.primary;
    final border = isSelected
        ? null
        : Border.all(color: AppColors.primary, width: 1.5);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: border,
        boxShadow: isSelected
            ? const [
                BoxShadow(
                  color: AppColors.primaryRing,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Icon(Icons.photo_camera_outlined, color: foreground),
    );
  }
}
