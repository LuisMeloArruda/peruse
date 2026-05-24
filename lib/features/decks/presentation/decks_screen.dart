import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peruse/core/router/routes.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/widgets/peruse_linear_progress.dart';
import 'package:peruse/core/widgets/peruse_sheet_card.dart';
import 'package:peruse/features/decks/domain/entities/deck.dart';
import 'package:peruse/features/decks/presentation/controller/decks_notifier.dart';

class DecksScreen extends ConsumerWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decksState = ref.watch(decksProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addDeck),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        child: const Icon(Icons.add_rounded),
      ),
      appBar: _DecksTopBar(onProfileTap: () {}),
      body: SafeArea(
        child: decksState.when(
          data: (decks) => Column(
            children: [
              Flexible(
                child: _DecksLoadedView(
                  decks: decks,
                  onCreateDeck: () => context.push(AppRoutes.addDeck),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            debugPrint('Decks load failed: $error');
            return Center(
              child: Text(
                'We could not load your decks right now.',
                style: context.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DecksLoadedView extends StatefulWidget {
  const _DecksLoadedView({required this.decks, required this.onCreateDeck});

  final List<AppDeck> decks;
  final VoidCallback onCreateDeck;

  @override
  State<_DecksLoadedView> createState() => _DecksLoadedViewState();
}

class _DecksLoadedViewState extends State<_DecksLoadedView> {
  bool _sortByRecent = false;

  @override
  Widget build(BuildContext context) {
    final decks = _sortByRecent
    ? ([...widget.decks]..sort(
        (left, right) => right.createdAt.compareTo(left.createdAt),
      ))
    : widget.decks;


    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          sliver: SliverToBoxAdapter(
            child: _DecksHeader(
              sortByRecent: _sortByRecent,
              onSortTap: () {
                setState(() {
                  _sortByRecent = !_sortByRecent;
                });
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: decks.isEmpty
              ? SliverToBoxAdapter(
                  child: _EmptyDeckState(onCreateDeck: widget.onCreateDeck),
                )
              : SliverList.separated(
                  itemCount: decks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final deck = decks[index];
                    final progress = _progressFor(deck);
                    final wordCount = _wordCountFor(deck);
                    final progressColor = _colorFromString(deck.color);
                    final icon = _iconFor(deck.icon);
                    final createdLabel = _formatCreatedDate(deck.createdAt);

                    return _DeckCard(
                      title: deck.name,
                      createdLabel: createdLabel,
                      wordCount: wordCount,
                      progress: progress,
                      accentColor: progressColor,
                      icon: icon,
                      onTap: () => context.push(AppRoutes.deckDetail(deck.id)),
                    );
                  },
                ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          sliver: SliverToBoxAdapter(
            child: _CreateDeckCard(onTap: widget.onCreateDeck),
          ),
        ),
      ],
    );
  }
}

class _DecksTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _DecksTopBar({required this.onProfileTap});
  final VoidCallback onProfileTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 50);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
      ).copyWith(top: AppSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Peruse',
              style: context.textTheme.titleLarge?.copyWith(
                color: AppColors.brandTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecksHeader extends StatelessWidget {
  const _DecksHeader({required this.sortByRecent, required this.onSortTap});

  final bool sortByRecent;
  final VoidCallback onSortTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VOCABULARY MASTERY',
          style: context.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'My Decks',
          style: context.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SortChip(
          label: sortByRecent ? 'Sorted by recent' : 'Sort by recent',
          onTap: onSortTap,
          isActive: sortByRecent,
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.onTap,
    required this.isActive,
  });

  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sort_rounded,
                size: 16,
                color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label.toUpperCase(),
                style: context.textTheme.labelSmall?.copyWith(
                  color: isActive ? AppColors.primary : null,
                  fontWeight: isActive ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.title,
    required this.createdLabel,
    required this.wordCount,
    required this.progress,
    required this.accentColor,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String createdLabel;
  final int wordCount;
  final double progress;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DeckImageHeader(accentColor: accentColor, icon: icon),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: context.textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _WordCountPill(count: wordCount),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(createdLabel, style: context.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  Text('STUDY PROGRESS', style: context.textTheme.labelSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  PeruseLinearProgress(progress: progress, color: accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckImageHeader extends StatelessWidget {
  const _DeckImageHeader({required this.accentColor, required this.icon});

  final Color accentColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.6),
            AppColors.surfaceContainer,
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(icon, color: accentColor, size: 32),
          ),
        ),
      ),
    );
  }
}

class _WordCountPill extends StatelessWidget {
  const _WordCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count words',
        style: context.textTheme.labelSmall?.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _CreateDeckCard extends StatelessWidget {
  const _CreateDeckCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(
              color: AppColors.neutralOutline,
              width: 1.2,
              style: BorderStyle.solid,
            ),
            color: AppColors.surfaceContainer,
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('New Vocabulary Set', style: context.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Start your next linguistic journey',
                style: context.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDeckState extends StatelessWidget {
  const _EmptyDeckState({required this.onCreateDeck});

  final VoidCallback onCreateDeck;

  @override
  Widget build(BuildContext context) {
    return PeruseSheetCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No decks yet', style: context.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Create your first vocabulary set and start building momentum.',
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onCreateDeck,
            child: const Text('Create deck'),
          ),
        ],
      ),
    );
  }
}

double _progressFor(AppDeck deck) {
  final seed = deck.id.hashCode.abs();
  final value = 0.2 + (seed % 70) / 100;
  return value.clamp(0.2, 0.9);
}

int _wordCountFor(AppDeck deck) {
  return 10 + (deck.id.hashCode.abs() % 40);
}

Color _colorFromString(String value) {
  final normalized = value.trim().toLowerCase();

  if (normalized.isEmpty) {
    return AppColors.primary;
  }

  if (normalized.startsWith('#')) {
    final hex = normalized.substring(1);
    return _colorFromHex(hex);
  }

  if (normalized.startsWith('0x')) {
    return _colorFromHex(normalized.substring(2));
  }

  return switch (normalized) {
    'green' => AppColors.primary,
    'blue' => const Color(0xFF2F6BFF),
    'orange' => const Color(0xFFF07A28),
    'red' => AppColors.error,
    'teal' => const Color(0xFF1BA49C),
    'purple' => const Color(0xFF6E56CF),
    _ => AppColors.primary,
  };
}

Color _colorFromHex(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6) {
    buffer.write('ff');
  }
  buffer.write(hex.replaceAll('#', ''));
  final value = int.tryParse(buffer.toString(), radix: 16);
  if (value == null) {
    return AppColors.primary;
  }
  return Color(value);
}

IconData _iconFor(String raw) {
  final normalized = raw.trim().toLowerCase();

  return switch (normalized) {
    'book' => Icons.menu_book_rounded,
    'layers' => Icons.layers_rounded,
    'globe' => Icons.public_rounded,
    'language' => Icons.record_voice_over_rounded,
    'travel' => Icons.luggage_rounded,
    'work' => Icons.work_rounded,
    'food' => Icons.restaurant_rounded,
    'music' => Icons.graphic_eq_rounded,
    'sports' => Icons.sports_soccer_rounded,
    'fitness' => Icons.fitness_center_rounded,
    'edit' => Icons.edit_rounded,
    'camera' => Icons.photo_camera_rounded,
    'brain' => Icons.psychology_rounded,
    'compass' => Icons.explore_rounded,
    'science' => Icons.science_rounded,
    'history' => Icons.account_balance_rounded,
    'culture' => Icons.theater_comedy_rounded,
    _ => Icons.auto_awesome_rounded,
  };
}

String _formatCreatedDate(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final month = _monthNames[date.month - 1];
  return 'Created $month ${date.day}, ${date.year}';
}

const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
