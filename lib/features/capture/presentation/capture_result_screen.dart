import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/features/capture/domain/entities/label.dart';
import 'package:peruse/features/capture/presentation/controller/capture_notifier.dart';
import 'package:peruse/features/capture/presentation/controller/capture_screen_notifier.dart';
import 'package:peruse/features/profile/presentation/controller/profile_notifier.dart';

class CaptureResultScreen extends ConsumerStatefulWidget {
  const CaptureResultScreen({super.key, required this.reviewData});

  final CaptureReviewData reviewData;

  @override
  ConsumerState<CaptureResultScreen> createState() =>
      _CaptureResultScreenState();
}

class _CaptureResultScreenState extends ConsumerState<CaptureResultScreen> {
  late final TextEditingController _textController;
  int _selectedIndex = 0;
  bool _saving = false;

  bool get _returnsWordToCaller =>
      widget.reviewData.launchTarget == CaptureLaunchTarget.addWord;

  List<CaptureSuggestion> get _options =>
      widget.reviewData.suggestions.take(5).toList();

  CaptureSuggestion? get _selectedOption {
    if (_options.isEmpty) {
      return null;
    }
    if (_selectedIndex < 0 || _selectedIndex >= _options.length) {
      return _options.first;
    }
    return _options[_selectedIndex];
  }

  @override
  void initState() {
    super.initState();
    final initial = _options.isNotEmpty ? _options.first.englishText : '';
    _textController = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _discard() async {
    if (_saving) return;
    context.pop();
  }

  Future<void> _saveSelectedLabel() async {
    final selected = _selectedOption;
    final typedText = _textController.text.trim();

    if (_saving || selected == null || typedText.isEmpty) {
      return;
    }

    final label = Label(
      text: typedText,
      confidence: selected.confidence,
      language: 'english',
    );

    if (_returnsWordToCaller) {
      context.pop(
        CapturedWordResult(
          text: label.text,
          imagePath: widget.reviewData.localPath,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await ref.read(captureControllerProvider.notifier).saveLocalCapture(
        widget.reviewData.localPath,
        [label],
      );

      try {
        await ref.read(captureControllerProvider.notifier).syncAll();
      } catch (_) {
        // Keep the local save even if sync fails.
      }

      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _selectOption(int index) {
    final option = _options[index];
    setState(() {
      _selectedIndex = index;
      _textController.text = option.englishText;
      _textController.selection = TextSelection.collapsed(
        offset: _textController.text.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final selected = _selectedOption;
    final actionLabel = _returnsWordToCaller ? 'Use Word' : 'Save Word';
    final canSave =
        !_saving && selected != null && _textController.text.trim().isNotEmpty;
    final preferredLanguage =
        ref.watch(profileProvider).asData?.value?.preferredLanguage ?? 'en';
    final showOnlyWord = preferredLanguage == 'en';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                Expanded(
                  flex: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: Image.file(
                          File(widget.reviewData.localPath),
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.28),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.35),
                            ],
                            stops: const [0, 0.4, 1],
                          ),
                        ),
                        child: const SizedBox.expand(),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _CircleIconButton(
                          icon: Icons.close,
                          onTap: _saving ? null : _discard,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 7,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DETECTED OBJECT',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      letterSpacing: 1.2,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _textController,
                                      enabled: !_saving,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: AppColors.surfaceContainer,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                          suffixIcon: const Icon(Icons.edit_outlined),
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  if (selected != null)
                                    _ConfidenceBadge(
                                      confidence: selected.confidence,
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              Text(
                                'Suggestions',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 12),
                              const _PoweredChip(label: 'ML KIT POWERED'),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (options.isEmpty)
                            const Expanded(
                              child: Center(
                                child: Text('No suggestions available.'),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.separated(
                                itemCount: options.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final option = options[index];
                                  final isSelected = index == _selectedIndex;

                                  return _SuggestionCard(
                                    option: option,
                                    showOnlyWord: showOnlyWord,
                                    isSelected: isSelected,
                                    rank: index + 1,
                                    onTap: _saving
                                        ? null
                                        : () => _selectOption(index),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saving ? null : _discard,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: Text(
                                    _returnsWordToCaller ? 'Cancel' : 'Discard',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: FilledButton(
                                  onPressed: canSave
                                      ? _saveSelectedLabel
                                      : null,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(actionLabel),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_saving) Container(color: Colors.black.withValues(alpha: 0.18)),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.option,
    required this.showOnlyWord,
    required this.isSelected,
    required this.rank,
    required this.onTap,
  });

  final CaptureSuggestion option;
  final bool showOnlyWord;
  final bool isSelected;
  final int rank;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final confidence = (option.confidence * 100).toStringAsFixed(0);

    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.1)
          : AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.category_outlined,
                  color: isSelected
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showOnlyWord || option.translatedText == option.englishText
                          ? option.englishText
                          : '${option.translatedText} -> ${option.englishText}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rank == 1
                          ? 'Primary classification'
                          : 'Alternative suggestion',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$confidence%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.onSurface,
                    ),
                  ),
                  Text(
                    'Confidence',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
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

class _PoweredChip extends StatelessWidget {
  const _PoweredChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final value = (confidence * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$value%',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          Text(
            'Selected confidence',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.onSurface),
        ),
      ),
    );
  }
}
