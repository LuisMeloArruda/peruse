import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/widgets/peruse_text_field.dart';
import 'package:peruse/features/decks/presentation/controller/deck_detail_notifier.dart';

class AddWordScreen extends ConsumerStatefulWidget {
  const AddWordScreen({super.key, required this.deckId});

  final String deckId;

  @override
  ConsumerState<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends ConsumerState<AddWordScreen> {
  final _wordController = TextEditingController();

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  Future<void> _saveWord() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      debugPrint('Word text is required.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a word.')),
      );
      return;
    }

    try {
      await ref
          .read(deckDetailProvider(widget.deckId).notifier)
          .addWord(word);
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
                    'Add Word',
                    style: context.textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              PeruseTextField(
                controller: _wordController,
                labelText: 'Word',
                hintText: 'e.g. Flight',
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saveWord(),
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
