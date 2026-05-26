import 'dart:io';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/core/localization/locale_ext.dart';
import 'package:peruse/core/router/routes.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/utils/assets.dart';
import 'package:peruse/core/widgets/peruse_stat_bento_card.dart';
import 'package:peruse/core/widgets/peruse_text_field.dart';
import 'package:peruse/features/decks/domain/entities/word.dart';
import 'package:peruse/features/decks/presentation/controller/deck_detail_notifier.dart';
import 'package:peruse/features/study/presentation/controller/study_metrics_providers.dart';
import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';

class DeckDetailScreen extends ConsumerWidget {
  const DeckDetailScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deckDetailProvider(deckId));
    final userId = ref.watch(authRepositoryProvider).currentUser?.id;

    double realAvgMastery = 0.0;
    if (userId != null) {
      final masteryState = ref.watch(
        deckMasteryProvider(DeckMasteryParams(userId: userId, deckId: deckId)),
      );
      realAvgMastery = masteryState.value?.accuracy ?? 0.0;
    }

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
                  title:
                      state.deck?.name ??
                      context.translate('deck_fallback_title'),
                  onBack: () => context.pop(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _DeckSummary(
                  bio: state.deck?.bio,
                  wordCount: state.words.length,
                  avgMastery: realAvgMastery,
                  onEditDeck: state.deck == null
                      ? null
                      : () => context.push(
                          AppRoutes.editDeck(deckId),
                          extra: state.deck,
                        ),
                  onDeleteDeck: state.deck == null
                      ? null
                      : () async {
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                title: Text(
                                  dialogContext.translate('delete_deck_title'),
                                ),
                                content: Text(
                                  dialogContext.translate(
                                    'delete_deck_message',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(false),
                                    child: Text(
                                      dialogContext.translate('cancel'),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(true),
                                    child: Text(
                                      dialogContext.translate('delete'),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );

                          if (shouldDelete != true) {
                            return;
                          }

                          await ref
                              .read(deckRepositoryProvider)
                              .deleteDeck(deckId);
                          if (context.mounted) {
                            context.go(AppRoutes.decks);
                          }
                        },
                  onStudyNow: () => context.push(AppRoutes.deckStudy(deckId)),
                  onAddWord: () => context.push(AppRoutes.deckAddWord(deckId)),
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
                  context.translate('word_library'),
                  style: context.textTheme.headlineMedium,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: PeruseTextField(
                  hintText: context.translate('search_in_deck_hint'),
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
                    onTap: () =>
                        context.push(AppRoutes.wordDetail(deckId, word.id)),
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
  const _DeckHeader({required this.title, required this.onBack});

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
        Expanded(child: Text(title, style: context.textTheme.headlineSmall)),
      ],
    );
  }
}

class _DeckSummary extends StatelessWidget {
  const _DeckSummary({
    required this.bio,
    required this.wordCount,
    required this.avgMastery,
    required this.onEditDeck,
    required this.onDeleteDeck,
    required this.onStudyNow,
    required this.onAddWord,
  });

  final String? bio;
  final int wordCount;
  final double avgMastery;
  final VoidCallback? onEditDeck;
  final Future<void> Function()? onDeleteDeck;
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
            context.translate('daily_vocabulary'),
            style: context.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: PeruseStatBentoCard(
              value: '$wordCount',
              label: context.translate('words_label'),
              variant: PeruseStatBentoVariant.muted,
              minHeight: 96,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: PeruseStatBentoCard(
              value: '${(avgMastery * 100).round()}%',
              label: context.translate('avg_mastery_label'),
              variant: PeruseStatBentoVariant.primary,
              minHeight: 96,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (bio != null && bio!.trim().isNotEmpty) ...[
            Text(
              context.translate('about_this_deck'),
              style: context.textTheme.labelMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              bio!.trim(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurface,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEditDeck,
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(context.translate('edit')),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDeleteDeck == null
                      ? null
                      : () => onDeleteDeck!(),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(context.translate('delete')),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: FilledButton.icon(
              onPressed: onStudyNow,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(context.translate('study_now')),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onAddWord,
            icon: const Icon(Icons.add_circle_outline),
            label: Text(context.translate('add_word')),
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

class _WordCard extends ConsumerWidget {
  const _WordCard({required this.word, required this.onTap});

  final AppWord word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WordImageHeader(imageUrl: word.imageUrl),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalize(word.text),
                    style: context.textTheme.titleLarge,
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
  const _WordImageHeader({required this.imageUrl});

  final String? imageUrl;

  Widget _placeholder() {
    return Image.asset(
      kAppIconAsset,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
    );
  }

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
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? (_isRemoteImage(imageUrl!)
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      imageBuilder: (context, imageProvider) => Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          ),
                        ),
                      ),
                      placeholder: (context, url) =>
                          Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, url, error) => _placeholder(),
                    )
                  : Image.file(
                      File(imageUrl!),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (_, _, _) => _placeholder(),
                    ))
            : _placeholder(),
      ),
    );
  }
}

bool _isRemoteImage(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) {
    return false;
  }
  return uri.scheme == 'http' || uri.scheme == 'https';
}

String _capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}
