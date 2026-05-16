import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:peruse/core/router/routes.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/widgets/peruse_stat_bento_card.dart';
import 'package:peruse/core/widgets/peruse_text_field.dart';
import 'package:peruse/features/decks/domain/entities/word.dart';
import 'package:peruse/features/decks/presentation/controller/deck_detail_notifier.dart';

class DeckDetailScreen extends ConsumerWidget {
  const DeckDetailScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deckDetailProvider(deckId));

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
                  AppSpacing.lg,
                ),
                child: _DeckHeader(
                  title: state.deck?.name ?? 'Deck',
                  onBack: () => context.pop(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _DeckSummary(
                  wordCount: state.words.length,
                  avgMastery: _averageMastery(state.words),
                  onStudyNow: () => context.push(
                    AppRoutes.deckStudy(deckId),
                  ),
                  onAddWord: () => context.push(
                    AppRoutes.deckAddWord(deckId),
                  ),
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
                child: Text(
                  'Word Library',
                  style: context.textTheme.headlineMedium,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: PeruseTextField(
                  hintText: 'Search in deck...',
                  prefixIcon: const Icon(Icons.search),
                    onChanged: (value) => ref
                      .read(deckDetailProvider(deckId).notifier)
                      .updateSearchQuery(value),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              sliver: SliverList.separated(
                itemCount: state.filteredWords.length,
                separatorBuilder: (_, _) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final word = state.filteredWords[index];
                  return _WordCard(
                    word: word,
                    onTap: () => context.push(
                      AppRoutes.wordDetail(deckId, word.id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckHeader extends StatelessWidget {
  const _DeckHeader({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.brandTitle,
        ),
        Expanded(
          child: Text(
            title,
            style: context.textTheme.headlineSmall,
          ),
        ),
        Container(
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
      ],
    );
  }
}

class _DeckSummary extends StatelessWidget {
  const _DeckSummary({
    required this.wordCount,
    required this.avgMastery,
    required this.onStudyNow,
    required this.onAddWord,
  });

  final int wordCount;
  final double avgMastery;
  final VoidCallback onStudyNow;
  final VoidCallback onAddWord;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Vocabulary',
            style: context.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: PeruseStatBentoCard(
                  value: '$wordCount',
                  label: 'Words',
                  variant: PeruseStatBentoVariant.muted,
                  minHeight: 96,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PeruseStatBentoCard(
                  value: '${(avgMastery * 100).round()}%',
                  label: 'Avg. Mastery',
                  variant: PeruseStatBentoVariant.primary,
                  minHeight: 96,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onStudyNow,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Study Now'),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onAddWord,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add Word'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.onSurface,
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
              side: const BorderSide(color: AppColors.neutralOutline),
            ),
          ),
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.word, required this.onTap});

  final AppWord word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final confidence = word.confidence.clamp(0.0, 1.0).toDouble();
    final badge = confidence >= 0.85 ? 'MASTERED' : 'LEARNING';
    final badgeColor = confidence >= 0.85
        ? AppColors.primary
        : const Color(0xFF1E5EFF);

    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WordImageHeader(
              imageUrl: word.imageUrl,
              badge: badge,
              badgeColor: badgeColor,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalize(word.text),
                    style: context.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Confidence',
                    style: context.textTheme.labelSmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: confidence,
                            minHeight: 6,
                            backgroundColor: AppColors.neutralOutline,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${(confidence * 100).round()}%',
                        style: context.textTheme.labelLarge?.copyWith(
                          color: badgeColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Icon(
                          Icons.volume_up_rounded,
                          size: 18,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
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

class _WordImageHeader extends StatelessWidget {
  const _WordImageHeader({
    required this.imageUrl,
    required this.badge,
    required this.badgeColor,
  });

  final String? imageUrl;
  final String badge;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      child: Stack(
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xxl),
              ),
              child: Image.network(
                imageUrl!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Positioned(
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                badge,
                style: context.textTheme.labelSmall?.copyWith(
                  color: badgeColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _averageMastery(List<AppWord> words) {
  if (words.isEmpty) {
    return 0;
  }
  final total = words.fold<double>(
    0,
    (sum, word) => sum + word.confidence.clamp(0.0, 1.0).toDouble(),
  );
  return total / words.length;
}

String _capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}
