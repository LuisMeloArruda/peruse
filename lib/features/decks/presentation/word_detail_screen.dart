import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:peruse/core/localization/locale_ext.dart';
import 'package:peruse/core/router/routes.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/utils/assets.dart';
import 'package:peruse/core/widgets/peruse_sheet_card.dart';
import 'package:peruse/features/decks/presentation/controller/word_detail_notifier.dart';
import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';

class WordDetailScreen extends ConsumerStatefulWidget {
  const WordDetailScreen({
    super.key,
    required this.deckId,
    required this.wordId,
  });

  final String deckId;
  final String wordId;

  @override
  ConsumerState<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends ConsumerState<WordDetailScreen> {
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String url) async {
    if (url.isEmpty) {
      debugPrint('No pronunciation audio available.');
      return;
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('Audio playback failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordState = ref.watch(wordDetailProvider(widget.wordId));

    return Scaffold(
      body: SafeArea(
        child: wordState.when(
          data: (state) {
            final details = state.details;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: AppColors.brandTitle,
                      ),
                      Expanded(
                        child: Text(
                          context.translate('lumina_lexicon'),
                          style: context.textTheme.titleLarge?.copyWith(
                            color: AppColors.brandTitle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _WordHeroImage(imageUrl: state.word.imageUrl),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    context.translate('vocabulary_entry'),
                    style: context.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.4,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _capitalize(state.word.text),
                          style: context.textTheme.displayLarge?.copyWith(
                            fontSize: 42,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: details?.audioUrl.trim().isNotEmpty == true
                            ? () => _playAudio(details!.audioUrl)
                            : null,
                        icon: Icon(
                          details?.audioUrl.trim().isNotEmpty == true
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                        ),
                        color: details?.audioUrl.trim().isNotEmpty == true
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant.withValues(
                                alpha: 0.45,
                              ),
                        tooltip: details?.audioUrl.trim().isNotEmpty == true
                            ? context.translate('play_audio')
                            : context.translate('no_audio_available'),
                      ),
                    ],
                  ),
                  if (details != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Row(
                        children: [
                          _InfoChip(label: details.partOfSpeech),
                          const SizedBox(width: AppSpacing.xs),
                          _InfoChip(label: details.phonetic),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            AppRoutes.editWord(widget.deckId, state.word.id),
                          ),
                          icon: const Icon(Icons.edit_rounded),
                          label: Text(context.translate('edit_word')),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: Text(
                                    dialogContext.translate(
                                      'delete_word_title',
                                    ),
                                  ),
                                  content: Text(
                                    dialogContext.translate(
                                      'delete_word_message',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(
                                        dialogContext,
                                      ).pop(false),
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
                                .removeWordFromDeck(
                                  widget.deckId,
                                  state.word.id,
                                );
                            if (context.mounted) {
                              context.go(AppRoutes.deckDetail(widget.deckId));
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: Text(context.translate('delete_word')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PeruseSheetCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(title: context.translate('definition')),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          state.definitionText,
                          style: context.textTheme.bodyLarge,
                        ),
                        if (state.exampleText.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            state.exampleText,
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            debugPrint('Word detail load failed: $error');
            return Center(
              child: Text(
                context.translate('word_load_error'),
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

class _WordHeroImage extends StatelessWidget {
  const _WordHeroImage({this.imageUrl});

  final String? imageUrl;

  Widget _placeholder() {
    return Image.asset(
      kImagePlaceholderAsset,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: imageUrl == null || imageUrl!.isEmpty
          ? const Center(child: Icon(Icons.image, size: 48))
          : ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              child: _isRemoteImage(imageUrl!)
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
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                      errorBuilder: (_, _, _) => _placeholder(),
                    ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: context.textTheme.titleMedium),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: context.textTheme.labelSmall),
    );
  }
}

String _capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}
