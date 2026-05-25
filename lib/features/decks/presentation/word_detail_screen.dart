import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/utils/assets.dart';
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
                            : AppColors.onSurfaceVariant.withValues(alpha: 0.45),
                        tooltip: details?.audioUrl.trim().isNotEmpty == true
                            ? 'Play audio'
                            : 'No audio available',
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
                          state.definitionText,
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
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                      errorBuilder: (_, _, _) => _placeholder(),
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