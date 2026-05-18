import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peruse/core/router/routes.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/features/capture/domain/entities/label.dart';
import 'package:peruse/features/capture/presentation/controller/capture_notifier.dart';
import 'package:peruse/features/capture/presentation/controller/capture_screen_notifier.dart';

class CaptureResultScreen extends ConsumerStatefulWidget {
  const CaptureResultScreen({super.key, required this.reviewData});

  final CaptureReviewData reviewData;

  @override
  ConsumerState<CaptureResultScreen> createState() => _CaptureResultScreenState();
}

class _CaptureResultScreenState extends ConsumerState<CaptureResultScreen> {
  bool _saving = false;
  bool _showSummary = false;
  Label? _selectedLabel;
  String _statusText = '';

  Future<void> _selectOption(Label label) async {
    setState(() => _saving = true);

    await ref
        .read(captureControllerProvider.notifier)
        .saveLocalCapture(widget.reviewData.localPath, [label]);

    var statusText = 'Saved locally';

    try {
      final uploaded = await ref
          .read(captureControllerProvider.notifier)
          .syncAll();
      if (uploaded) {
        statusText = 'Saved locally and uploaded';
      } else {
        statusText = 'Saved locally, upload will retry automatically';
      }
    } catch (_) {
      statusText = 'Saved locally, upload will retry automatically';
    }

    if (!mounted) return;

    if (!mounted) return;

    setState(() => _saving = false);

    context.go(AppRoutes.captureList);
    return;
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.reviewData.labels.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_showSummary ? 'Capture saved' : 'Choose the right answer'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(widget.reviewData.localPath),
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      if (_saving)
                        Container(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (!_showSummary) ...[
                Text(
                  'MLKit is only a suggestion engine and can miss the correct object. Pick the best answer from the top 5 options.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Top 5 options',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (options.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No options available.'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final label = options[index];

                        return Material(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: _saving ? null : () => _selectOption(label),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              child: Text(
                                label.text,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selected name',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedLabel?.text ?? '-',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusText,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.captureList),
                  child: const Text('Done'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}