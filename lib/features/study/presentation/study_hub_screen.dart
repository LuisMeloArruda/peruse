import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:peruse/core/router/routes.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/widgets/peruse_sheet_card.dart';
import 'package:peruse/features/decks/domain/entities/deck.dart';
import 'package:peruse/features/study/presentation/controller/study_focus_provider.dart';

class StudyHubScreen extends ConsumerWidget {
  const StudyHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksState = ref.watch(studyDecksProvider);
    final activeDeckId = ref.watch(activeStudyDeckIdProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: _StudyHeader(
                  onMenuTap: () {},
                  onProfileTap: () {},
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: decksState.when(
                  data: (decks) {
                    final options = decks;
                    final resolvedId = _resolveActiveDeckId(
                      currentId: activeDeckId,
                      decks: options,
                    );

                    if (resolvedId != activeDeckId) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref
                            .read(activeStudyDeckIdProvider.notifier)
                            .set(resolvedId);
                      });
                    }

                    return _FocusDropdown(
                      decks: options,
                      activeDeckId: resolvedId,
                      onChanged: (value) => ref
                          .read(activeStudyDeckIdProvider.notifier)
                          .set(value),
                    );
                  },
                  loading: () => const _FocusLoading(),
                  error: (error, stackTrace) => _FocusError(message: '$error'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How do you want to study?'.toUpperCase(),
                      style: context.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.1,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Choose a mode',
                      style: context.textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _ModeCard(
                      title: 'Flashcards',
                      subtitle:
                          'Visual association training. See the image, recall the word.',
                      icon: Icons.auto_awesome,
                      onTap: () => _startFlashcards(
                        context,
                        ref,
                        activeDeckId,
                      ),
                      accent: Color(0xFF006A28),
                      gradient: [Color(0xFF1C1C1B), Color(0xFF0E0E0E)],
                    ),
                    SizedBox(height: AppSpacing.md),
                    _ModeCard(
                      title: 'Quiz',
                      subtitle: 'Multiple choice to test recognition speed.',
                      icon: Icons.quiz_outlined,
                      onTap: () => _showModeComingSoon(context),
                      accent: Color(0xFF1E5EFF),
                      gradient: [Color(0xFFE9F0FF), Color(0xFFFFFFFF)],
                    ),
                    SizedBox(height: AppSpacing.md),
                    _ModeCard(
                      title: 'Write It',
                      subtitle: 'Type the translation from memory.',
                      icon: Icons.edit_note,
                      badge: 'EXPERT MODE',
                      onTap: () => _showModeComingSoon(context),
                      accent: Color(0xFFF9B233),
                      gradient: [Color(0xFFFFF3D6), Color(0xFFFFFFFF)],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveActiveDeckId({
    required String? currentId,
    required List<AppDeck> decks,
  }) {
    if (decks.isEmpty) return null;
    if (currentId == null) return decks.first.id;
    final exists = decks.any((deck) => deck.id == currentId);
    return exists ? currentId : decks.first.id;
  }
}

void _showModeComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Coming soon.')),
  );
}

Future<void> _startFlashcards(
  BuildContext context,
  WidgetRef ref,
  String? deckId,
) async {
  if (deckId == null || deckId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select a deck to start.')),
    );
    return;
  }

  if (context.mounted) {
    context.push(AppRoutes.deckStudy(deckId));
  }
}

class _StudyHeader extends StatelessWidget {
  const _StudyHeader({required this.onMenuTap, required this.onProfileTap});

  final VoidCallback onMenuTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onMenuTap,
          icon: const Icon(Icons.menu_rounded),
          color: AppColors.brandTitle,
        ),
        Expanded(
          child: Text(
            'Study',
            style: context.textTheme.titleLarge?.copyWith(
              color: AppColors.brandTitle,
            ),
          ),
        ),
        GestureDetector(
          onTap: onProfileTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _FocusDropdown extends StatelessWidget {
  const _FocusDropdown({
    required this.decks,
    required this.activeDeckId,
    required this.onChanged,
  });

  final List<AppDeck> decks;
  final String? activeDeckId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Focus'.toUpperCase(),
          style: context.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.1,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        PeruseSheetCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          radius: AppRadius.xl,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: activeDeckId,
              hint: Text(
                'Select a deck',
                style: context.textTheme.bodyMedium,
              ),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: decks
                  .map<DropdownMenuItem<String>>(
                    (deck) => DropdownMenuItem<String>(
                      value: deck.id,
                      child: Text(
                        deck.name,
                        style: context.textTheme.titleMedium,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _FocusLoading extends StatelessWidget {
  const _FocusLoading();

  @override
  Widget build(BuildContext context) {
    return PeruseSheetCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.xl,
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('Loading decks...', style: context.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _FocusError extends StatelessWidget {
  const _FocusError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PeruseSheetCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.xl,
      child: Text(
        'Decks unavailable: $message',
        style: context.textTheme.bodyMedium,
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.gradient,
    this.onTap,
    this.chip,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<Color> gradient;
  final VoidCallback? onTap;
  final String? chip;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return PeruseSheetCard(
      radius: AppRadius.xxl,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xxl),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    bottom: -24,
                    right: -12,
                    child: Icon(
                      icon,
                      size: 140,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  if (chip != null)
                    Positioned(
                      top: AppSpacing.md,
                      left: AppSpacing.md,
                      child: _Chip(label: chip!, accent: accent),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: context.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(icon, color: accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _Badge(label: badge!, accent: accent),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerRight,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: accent.withValues(alpha: 0.14),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: accent,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: accent,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
