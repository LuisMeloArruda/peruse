import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:peruse/core/localization/locale_ext.dart';
import 'package:peruse/core/router/routes.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/widgets/peruse_text_field.dart';
import 'package:peruse/features/decks/domain/entities/word.dart';
import 'package:peruse/features/decks/data/repositories/deck_repository_impl.dart';
import 'package:peruse/features/capture/presentation/controller/capture_screen_notifier.dart';
import 'package:peruse/features/decks/presentation/controller/deck_detail_notifier.dart';

class AddWordScreen extends ConsumerStatefulWidget {
  const AddWordScreen({super.key, required this.deckId, this.wordId});

  final String deckId;
  final String? wordId;

  @override
  ConsumerState<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends ConsumerState<AddWordScreen> {
  final _wordController = TextEditingController();
  String? _imagePath;
  AppWord? _existingWord;
  bool _isLoadingWord = false;

  @override
  void initState() {
    super.initState();
    if (widget.wordId != null) {
      _loadWord();
    }
  }

  Future<void> _captureWord() async {
    final capturedWord = await context.push<CapturedWordResult>(
      AppRoutes.capture,
      extra: CaptureLaunchTarget.addWord,
    );

    if (!mounted || capturedWord == null) {
      return;
    }

    final normalized = capturedWord.text.trim();
    if (normalized.isEmpty) {
      return;
    }

    _wordController.text = normalized;
    _imagePath = capturedWord.imagePath;
    _wordController.selection = TextSelection.collapsed(
      offset: _wordController.text.length,
    );
  }

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  Future<void> _loadWord() async {
    if (_isLoadingWord) {
      return;
    }

    setState(() {
      _isLoadingWord = true;
    });

    final repository = ref.read(deckRepositoryProvider);
    final word = await repository.getWordById(widget.wordId!);
    if (!mounted) {
      return;
    }

    if (word == null) {
      setState(() {
        _isLoadingWord = false;
      });
      return;
    }

    setState(() {
      _existingWord = word;
      _wordController.text = word.text;
      _imagePath = word.imageUrl;
      _isLoadingWord = false;
    });
  }

  Future<void> _saveWord() async {
    if (widget.wordId != null && _existingWord == null) {
      await _loadWord();
    }

    if (widget.wordId != null && _existingWord == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.translate('word_loading_wait')),
          ),
        );
      }
      return;
    }

    final word = _wordController.text.trim();
    if (word.isEmpty) {
      debugPrint('Word text is required.');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(context.translate('word_required'))),
        );
      }
      return;
    }

    try {
      final repository = ref.read(deckRepositoryProvider);
      if (_existingWord == null) {
        await ref
            .read(deckDetailProvider(widget.deckId).notifier)
            .addWord(word, imageUrl: _imagePath);
      } else {
        await repository.updateWord(
          AppWord(
            id: _existingWord!.id,
            text: word,
            imageUrl: _imagePath,
            confidence: _existingWord!.confidence,
            sourceScanId: _existingWord!.sourceScanId,
            createdAt: _existingWord!.createdAt,
          ),
        );
      }
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      debugPrint('Add word failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
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
                  Text(
                    widget.wordId == null
                        ? context.translate('add_word_title')
                        : context.translate('edit_word_title'),
                    style: context.textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              PeruseTextField(
                controller: _wordController,
                labelText: context.translate('word_label'),
                hintText: context.translate('word_hint'),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saveWord(),
                suffixIcon: IconButton(
                  onPressed: _captureWord,
                  icon: const Icon(Icons.photo_camera_outlined),
                  color: AppColors.onSurfaceVariant,
                  tooltip: context.translate('capture_word_tooltip'),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _isLoadingWord ? null : _saveWord,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  widget.wordId == null
                      ? context.translate('save_word')
                      : context.translate('update_word'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
