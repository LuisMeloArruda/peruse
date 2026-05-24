import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:peruse/core/router/routes.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/widgets/peruse_text_field.dart';
import 'package:peruse/features/capture/presentation/controller/capture_screen_notifier.dart';
import 'package:peruse/features/decks/presentation/controller/deck_detail_notifier.dart';

class AddWordScreen extends ConsumerStatefulWidget {
  const AddWordScreen({super.key, required this.deckId});

  final String deckId;

  @override
  ConsumerState<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends ConsumerState<AddWordScreen> {
  final _wordController = TextEditingController();
  String? _imagePath;

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

  Future<void> _saveWord() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      debugPrint('Word text is required.');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a word.')));
      return;
    }

    try {
      await ref
          .read(deckDetailProvider(widget.deckId).notifier)
          .addWord(word, imageUrl: _imagePath);
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
                  Text('Add Word', style: context.textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              PeruseTextField(
                controller: _wordController,
                labelText: 'Word',
                hintText: 'e.g. Flight',
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saveWord(),
                suffixIcon: IconButton(
                  onPressed: _captureWord,
                  icon: const Icon(Icons.photo_camera_outlined),
                  color: AppColors.onSurfaceVariant,
                  tooltip: 'Capture word',
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _saveWord,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Save Word'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
