import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:peruse/core/router/router.dart';
import 'package:peruse/core/router/routes.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/utils/assets.dart';
import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';
import 'package:peruse/features/decks/presentation/controller/deck_detail_notifier.dart';
import 'package:peruse/features/decks/presentation/controller/word_audio_provider.dart';
import 'package:peruse/features/flashcards/domain/entities/flashcard.dart';
import 'package:peruse/features/flashcards/presentation/controller/flashcard_notifier.dart';
import 'package:peruse/features/flashcards/presentation/controller/study_session_notifier.dart';
import 'package:peruse/core/llm/models/llm_request.dart';
import 'package:peruse/core/llm/provider/llm_providers.dart';
import 'package:peruse/features/profile/presentation/controller/profile_notifier.dart';
import 'package:peruse/features/profile/domain/profile_languages.dart';

class FlashcardStudyScreen extends ConsumerStatefulWidget {
  const FlashcardStudyScreen({super.key, required this.deckId});

  final String deckId;

  @override
  ConsumerState<FlashcardStudyScreen> createState() => _FlashcardStudyScreenState();
}

class _FlashcardStudyScreenState extends ConsumerState<FlashcardStudyScreen>
    with RouteAware {
  late final AudioPlayer _audioPlayer;
  late final Stopwatch _stopwatch;
  ProviderSubscription<FlashcardStudyState>? _flashcardSub;
  String? _activeCardId;
  bool _endRequested = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _stopwatch = Stopwatch();

    _flashcardSub = ref.listenManual<FlashcardStudyState>(
      flashcardStudyProvider(widget.deckId),
      (previous, next) {
        final nextId = next.currentCard?.id;
        if (nextId != null && nextId != _activeCardId) {
          _activeCardId = nextId;
          _restartStopwatch();
        }

        if (!next.isLoading && next.currentCard == null) {
          _stopwatch.stop();
          _requestEndSession();
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureSession();
    });
  }

  @override
  void didUpdateWidget(covariant FlashcardStudyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deckId != widget.deckId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureSession();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _flashcardSub?.close();
    _audioPlayer.dispose();
    _stopwatch.stop();

    super.dispose();
  }

  @override
  void didPushNext() {
    _requestEndSession();
  }

  @override
  void didPop() {
    _requestEndSession();
  }

  void _requestEndSession() {
    if (_endRequested) return;
    _endRequested = true;
    Future.microtask(() {
      if (!mounted) return;
      ref.read(studySessionProvider.notifier).endSession();
    });
  }

  void _ensureSession() {
    final notifier = ref.read(studySessionProvider.notifier);
    final session = ref.read(studySessionProvider);

    final isSameSession = session.sessionId != null &&
        session.deckId == widget.deckId &&
        session.mode == 'flashcards' &&
        !session.isCompleted;

    if (isSameSession) return;

    notifier.resetSession();
    notifier.startSession(deckId: widget.deckId, mode: 'flashcards');
  }

  void _restartStopwatch() {
    _stopwatch
      ..reset()
      ..start();
  }

  int _stopwatchElapsed() {
    _stopwatch.stop();
    return _stopwatch.elapsedMilliseconds;
  }

  Future<void> _gradeCard(AppFlashcard card, bool correct) async {
    final elapsed = _stopwatchElapsed();
    await ref
        .read(studySessionProvider.notifier)
        .gradeWord(wordId: card.wordId, correct: correct, elapsedMillis: elapsed);
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
    await context.push(AppRoutes.editWord(widget.deckId, card.wordId));
  }

  Future<void> _deleteCurrentCard(AppFlashcard card) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete word?'),
          content: const Text(
            'This removes the word from the current deck and queues the delete for sync.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await ref.read(deckRepositoryProvider).removeWordFromDeck(widget.deckId, card.wordId);
    if (mounted) {
      context.go(AppRoutes.deckDetail(widget.deckId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final deckState = ref.watch(deckDetailProvider(widget.deckId));
    final flashcardState = ref.watch(flashcardStudyProvider(widget.deckId));
    final sessionState = ref.watch(studySessionProvider);
    final flashcardNotifier = ref.read(flashcardStudyProvider(widget.deckId).notifier);

    final deckName = deckState.deck?.name ?? 'Study Session';
    final currentCard = flashcardState.currentCard;
    final currentAudioUrl = currentCard == null
      ? null
      : ref.watch(wordAudioUrlProvider(currentCard.wordId)).value;
    final hasAudio = currentAudioUrl != null && currentAudioUrl.trim().isNotEmpty;
    
    final totalCount = sessionState.totalCount;
    final currentCount = totalCount == 0 ? 0 : math.min(sessionState.currentIndex + 1, totalCount);
    final progressValue = totalCount == 0 ? 0.0 : currentCount / totalCount;

    return WillPopScope(
      onWillPop: () async {
        _requestEndSession();
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F4EF),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: flashcardState.isLoading ||
                    sessionState.isLoading ||
                    sessionState.deckId != widget.deckId ||
                    sessionState.mode != 'flashcards'
                ? const Center(child: CircularProgressIndicator())
                : sessionState.isCompleted
                    ? _CompletionState(
                        deckName: deckName,
                        onBack: () => context.pop(),
                      )
                    : Column(
                        children: [
                        Expanded(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _CircleButton(
                                    icon: Icons.close,
                                    onTap: () async {
                                      _requestEndSession();
                                      if (mounted) {
                                        context.pop();
                                      }
                                    },
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'CURRENT DECK',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                letterSpacing: 1.3,
                                                color: AppColors.onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          deckName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
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
                                            backgroundColor:
                                                const Color(0xFFE0DDD5),
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              if (currentCard != null)
                                Expanded(
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: () => flashcardNotifier.toggleFlip(),
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 280),
                                        switchInCurve: Curves.easeOutBack,
                                        switchOutCurve: Curves.easeIn,
                                        transitionBuilder: (child, animation) {
                                          final rotate =
                                              Tween<double>(begin: math.pi, end: 0)
                                                  .animate(animation);
                                          return AnimatedBuilder(
                                            animation: rotate,
                                            child: child,
                                            builder: (context, child) {
                                              final value = rotate.value;
                                              final isUnder = value > math.pi / 2;
                                              final displayValue =
                                                  isUnder ? value - math.pi : value;
                                              return Transform(
                                                alignment: Alignment.center,
                                                transform:
                                                    Matrix4.rotationY(displayValue),
                                                child: child,
                                              );
                                            },
                                          );
                                        },
                                        child: _FlashcardCard(
                                          key: ValueKey(
                                            '${currentCard.id}-${flashcardState.isFlipped}',
                                          ),
                                          card: currentCard,
                                          isFlipped: flashcardState.isFlipped,
                                          hasAudio: hasAudio,
                                          onAudioTap: () => _playAudio(currentCard),
                                          onEditTap: () => _editCurrentCard(currentCard),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox.shrink()),
                              const SizedBox(height: AppSpacing.lg),
                              if (currentCard != null)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _MiniAction(
                                      icon: hasAudio
                                          ? Icons.volume_up_rounded
                                          : Icons.volume_off_rounded,
                                      label: hasAudio ? 'Audio' : 'No Audio',
                                      enabled: hasAudio,
                                      onTap: () => _playAudio(currentCard),
                                    ),
                                    _MiniAction(
                                      icon: Icons.edit_rounded,
                                      label: 'Edit',
                                      enabled: true,
                                      onTap: () => _editCurrentCard(currentCard),
                                    ),
                                    _MiniAction(
                                      icon: Icons.delete_outline_rounded,
                                      label: 'Delete',
                                      enabled: true,
                                      onTap: () => _deleteCurrentCard(currentCard),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (currentCard != null)
                          Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  label: 'TRY AGAIN',
                                  icon: Icons.close_rounded,
                                  backgroundColor: const Color(0xFFE2E6E4),
                                  foregroundColor: const Color(0xFFC7351D),
                                  onTap: () async {
                                    await _gradeCard(currentCard, false);
                                    await flashcardNotifier.markTryAgain();
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _ActionButton(
                                  label: 'GOT IT',
                                  icon: Icons.check_rounded,
                                  backgroundColor: const Color(0xFF53D769),
                                  foregroundColor: Colors.white,
                                  onTap: () async {
                                    await _gradeCard(currentCard, true);
                                    await flashcardNotifier.markGotIt();
                                  },
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}

class _FlashcardCard extends ConsumerWidget {
  const _FlashcardCard({
    super.key,
    required this.card,
    required this.isFlipped,
    required this.hasAudio,
    required this.onAudioTap,
    required this.onEditTap,
  });

  final AppFlashcard card;
  final bool isFlipped;
  final bool hasAudio;
  final VoidCallback onAudioTap;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaHeight = MediaQuery.of(context).size.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : mediaHeight * 0.62;
        final cardHeight = availableHeight.clamp(360.0, 520.0).toDouble();
        final imageHeight = (cardHeight * 0.42).clamp(160.0, 220.0).toDouble();

        return SizedBox(
          width: double.infinity,
          height: cardHeight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
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
              mainAxisSize: MainAxisSize.max,
              children: [
                _CardImage(mediaUrl: card.mediaUrl, height: imageHeight),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: isFlipped
                  ? Column(
                      key: const ValueKey('back'),
                      mainAxisSize: MainAxisSize.max,
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
                        Expanded(
                          child: Builder(
                            builder: (context) {
                            final profileState = ref.watch(profileProvider);
                            final preferredLanguageCode =
                                profileState.asData?.value?.preferredLanguage ?? 'en';

                            final originalBackText = card.backText?.trim();
                            final hasBackText = originalBackText?.isNotEmpty == true;
                            final fallbackText =
                                hasBackText ? originalBackText! : 'No back text yet.';

                            final textStyle = Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                );

                            Widget buildScrollableText(String text) {
                              return Align(
                                alignment: Alignment.topCenter,
                                child: SingleChildScrollView(
                                  child: Text(
                                    text,
                                    textAlign: TextAlign.center,
                                    style: textStyle,
                                  ),
                                ),
                              );
                            }

                            if (preferredLanguageCode == 'en' || !hasBackText) {
                              return buildScrollableText(fallbackText);
                            }

                            final targetLanguage =
                                profileLanguageLabel(preferredLanguageCode).toLowerCase();
                            final cacheKey = llmCacheKey(targetLanguage, fallbackText);
                            final cache = ref.watch(llmTranslationCacheProvider);
                            final cachedTranslation = cache[cacheKey];

                            if (cachedTranslation != null && cachedTranslation.isNotEmpty) {
                              return buildScrollableText(cachedTranslation);
                            }

                            final request = LlmRequest(
                              input: {fallbackText: 1},
                              sourceLanguage: 'english',
                              targetLanguage: targetLanguage,
                            );

                            final translation = ref.watch(llmTranslateProvider(request));
                            return translation.when(
                              data: (output) {
                                final translated = output.translatedTexts.isNotEmpty
                                    ? output.translatedTexts.values.first
                                    : fallbackText;

                                if (translated.isNotEmpty && cache[cacheKey] != translated) {
                                  Future.microtask(
                                    () => ref
                                        .read(llmTranslationCacheProvider.notifier)
                                        .put(cacheKey, translated),
                                  );
                                }

                                return buildScrollableText(translated);
                              },
                              loading: () => buildScrollableText(fallbackText),
                              error: (_, _) {
                                if (cache[cacheKey] == null) {
                                  Future.microtask(
                                    () => ref
                                        .read(llmTranslationCacheProvider.notifier)
                                        .put(cacheKey, fallbackText),
                                  );
                                }
                                return buildScrollableText(fallbackText);
                              },
                            );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          card.frontText ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('front'),
                      mainAxisSize: MainAxisSize.max,
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
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Text(
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
                            ),
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.mediaUrl, required this.height});

  final String? mediaUrl;
  final double height;

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
    final resolvedUrl = mediaUrl?.trim() ?? '';
    return Container(
      height: height,
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
                fit: BoxFit.contain,
                alignment: Alignment.center,
                errorBuilder: (_, _, _) => _placeholder(),
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
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: enabled ? onTap : null,
      radius: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: enabled
                ? AppColors.onSurfaceVariant
                : AppColors.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: enabled
                      ? AppColors.onSurfaceVariant
                      : AppColors.onSurfaceVariant.withValues(alpha: 0.45),
                ),
          ),
        ],
      ),
    );
  }
}

class _CompletionState extends StatelessWidget {
  const _CompletionState({
    required this.deckName,
    required this.onBack,
  });

  final String deckName;
  final VoidCallback onBack;

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
            'You finished this round. Congratulations!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(onPressed: onBack, child: const Text('Back')),
        ],
      ),
    );
  }
}
