import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/widgets/peruse_sheet_card.dart';
import 'package:peruse/features/decks/presentation/controller/word_detail_notifier.dart';

class WordDetailScreen extends ConsumerStatefulWidget {
  const WordDetailScreen({super.key, required this.wordId});

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
                          'Lumina Lexicon',
                          style: context.textTheme.titleLarge?.copyWith(
                            color: AppColors.brandTitle,
                          ),
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 20,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _WordHeroImage(imageUrl: state.word.imageUrl),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'VOCABULARY ENTRY',
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
                      if (details != null)
                        IconButton(
                          onPressed: () => _playAudio(details.audioUrl),
                          icon: const Icon(Icons.volume_up_rounded),
                          color: AppColors.primary,
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
                  PeruseSheetCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(title: 'Definition'),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          details?.definition ?? 'No definition available yet.',
                          style: context.textTheme.bodyLarge,
                        ),
                        if (details != null && details.example.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            details.example,
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PeruseSheetCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(title: 'Mastery'),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${(state.word.confidence.clamp(0, 1) * 100).round()}%',
                          style: context.textTheme.headlineSmall?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: state.word.confidence.clamp(0, 1),
                            minHeight: 8,
                            backgroundColor: AppColors.neutralOutline,
                            color: AppColors.primary,
                          ),
                        ),
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
                'We could not load this word right now.',
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
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.image_not_supported_rounded),
                ),
              ),
            ),
    );
  }
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
      child: Text(
        label,
        style: context.textTheme.labelSmall,
      ),
    );
  }
}

String _capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}
