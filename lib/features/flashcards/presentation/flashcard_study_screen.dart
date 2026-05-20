import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';
import 'package:peruse/features/decks/presentation/controller/deck_detail_notifier.dart';
import 'package:peruse/features/flashcards/domain/entities/flashcard.dart';
import 'package:peruse/features/flashcards/presentation/controller/flashcard_notifier.dart';

class FlashcardStudyScreen extends ConsumerStatefulWidget {
  const FlashcardStudyScreen({super.key, required this.deckId});

  final String deckId;

  @override
  ConsumerState<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends ConsumerState<FlashcardStudyScreen> {
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

  Future<void> _playAudio(AppFlashcard card) async {
    try {
      final repository = ref.read(deckRepositoryProvider);
      final word = await repository.getWordById(card.wordId);
      if (word == null) return;

      final details = await repository.getWordDetails(word);
      final audioUrl = details?.audioUrl.trim() ?? '';
      if (audioUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio is available for this card.')),
        );
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(audioUrl));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio playback failed: $error')),
      );
    }
  }

  Future<void> _editCurrentCard(AppFlashcard card) async {
    final frontController = TextEditingController(text: card.frontText ?? '');
    final backController = TextEditingController(text: card.backText ?? '');

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit flashcard', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: frontController,
                  decoration: const InputDecoration(labelText: 'Front text'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: backController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Back text'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldSave != true || !mounted) {
      frontController.dispose();
      backController.dispose();
      return;
    }

    await ref
      .read(flashcardStudyProvider(widget.deckId).notifier)
        .updateCurrentCard(
          frontText: frontController.text.trim().isEmpty
              ? null
              : frontController.text.trim(),
          backText: backController.text.trim().isEmpty
              ? null
              : backController.text.trim(),
        );

    frontController.dispose();
    backController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deckState = ref.watch(deckDetailProvider(widget.deckId));
    final flashcardState = ref.watch(flashcardStudyProvider(widget.deckId));
    final flashcardNotifier = ref.read(
      flashcardStudyProvider(widget.deckId).notifier,
    );

    final deckName = deckState.deck?.name ?? 'Study Session';
    final currentCard = flashcardState.currentCard;
    final totalCount = math.max(flashcardState.totalCount, 0);
    final currentCount = currentCard == null
        ? flashcardState.completedCount
        : flashcardState.completedCount + 1;
    final progressValue = totalCount == 0 ? 0.0 : currentCount / totalCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: flashcardState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : currentCard == null
              ? _CompletionState(
                  deckName: deckName,
                  onBack: () => context.pop(),
                  onRefresh: () => flashcardNotifier.refresh(),
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        _CircleButton(
                          icon: Icons.close,
                          onTap: () => context.pop(),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CURRENT DECK',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      letterSpacing: 1.3,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                deckName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$currentCount/$totalCount',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 76,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 6,
                                  value: progressValue,
                                  backgroundColor: const Color(0xFFE0DDD5),
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: () => flashcardNotifier.toggleFlip(),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutBack,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              final rotate = Tween<double>(begin: math.pi, end: 0)
                                  .animate(animation);
                              return AnimatedBuilder(
                                animation: rotate,
                                child: child,
                                builder: (context, child) {
                                  final value = rotate.value;
                                  final isUnder = value > math.pi / 2;
                                  final displayValue = isUnder ? value - math.pi : value;
                                  return Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.rotationY(displayValue),
                                    child: child,
                                  );
                                },
                              );
                            },
                            child: _FlashcardCard(
                              key: ValueKey('${currentCard.id}-${flashcardState.isFlipped}'),
                              card: currentCard,
                              isFlipped: flashcardState.isFlipped,
                              onAudioTap: () => _playAudio(currentCard),
                              onSaveTap: () => flashcardNotifier.saveCurrentCard(),
                              onEditTap: () => _editCurrentCard(currentCard),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'TRY AGAIN',
                            icon: Icons.close_rounded,
                            backgroundColor: const Color(0xFFE2E6E4),
                            foregroundColor: const Color(0xFFC7351D),
                            onTap: () => flashcardNotifier.markTryAgain(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _ActionButton(
                            label: 'GOT IT',
                            icon: Icons.check_rounded,
                            backgroundColor: const Color(0xFF53D769),
                            foregroundColor: Colors.white,
                            onTap: () => flashcardNotifier.markGotIt(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _MiniAction(
                          icon: Icons.volume_up_rounded,
                          label: 'Audio',
                          onTap: () => _playAudio(currentCard),
                        ),
                        _MiniAction(
                          icon: Icons.star_border_rounded,
                          label: 'Save',
                          onTap: () => flashcardNotifier.saveCurrentCard(),
                        ),
                        _MiniAction(
                          icon: Icons.edit_rounded,
                          label: 'Edit',
                          onTap: () => _editCurrentCard(currentCard),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FlashcardCard extends StatelessWidget {
  const _FlashcardCard({
    super.key,
    required this.card,
    required this.isFlipped,
    required this.onAudioTap,
    required this.onSaveTap,
    required this.onEditTap,
  });

  final AppFlashcard card;
  final bool isFlipped;
  final VoidCallback onAudioTap;
  final VoidCallback onSaveTap;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 360, minHeight: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardImage(mediaUrl: card.mediaUrl),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: isFlipped
                  ? Column(
                      key: const ValueKey('back'),
                      children: [
                        Text(
                          'ANSWER',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                letterSpacing: 1.6,
                                color: const Color(0xFF7E8DB8),
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          card.backText?.isNotEmpty == true
                              ? card.backText!
                              : 'No back text yet.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          card.frontText ?? '',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('front'),
                      children: [
                        Text(
                          'VISUAL PROMPT',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                letterSpacing: 1.6,
                                color: const Color(0xFF6A8FF6),
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          card.frontText?.isNotEmpty == true
                              ? card.frontText!
                              : 'Untitled card',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap to flip',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CardIconButton(
                  icon: Icons.volume_up_rounded,
                  onTap: onAudioTap,
                ),
                _CardIconButton(
                  icon: Icons.star_border_rounded,
                  onTap: onSaveTap,
                ),
                _CardIconButton(
                  icon: Icons.edit_rounded,
                  onTap: onEditTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.mediaUrl});

  final String? mediaUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = mediaUrl?.trim() ?? '';
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: resolvedUrl.isEmpty
            ? const Center(
                child: Icon(Icons.auto_stories_rounded, color: Colors.white, size: 64),
              )
            : Image.network(
                resolvedUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.image_not_supported_rounded, color: Colors.white70, size: 48),
                ),
              ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: foregroundColor.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F3F1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, color: AppColors.onSurfaceVariant),
      ),
    );
  }
}

class _CompletionState extends StatelessWidget {
  const _CompletionState({
    required this.deckName,
    required this.onBack,
    required this.onRefresh,
  });

  final String deckName;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            deckName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'You finished this round. Pull new edits from sync or start again.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(onPressed: onBack, child: const Text('Back')),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(onPressed: onRefresh, child: const Text('Refresh')),
            ],
          ),
        ],
      ),
    );
  }
}