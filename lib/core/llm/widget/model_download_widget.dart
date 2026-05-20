import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peruse/core/llm/models/llm_request.dart';
import 'package:peruse/core/llm/provider/llm_providers.dart';
import 'package:peruse/core/theme/app_colors.dart';
import 'package:peruse/core/theme/app_spacing.dart';

class TranslationWidget extends ConsumerWidget {
  const TranslationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              const Text('AI Translation Ready'),
            ],
          ),
          TextButton(
            onPressed: () {
              final future = ref.read(
                llmTranslateProvider(
                  LlmRequest(prompt: 'Good morning'),
                ),
              );
              future.when(
                data: (output) {
                  log(
                    '${output.sourceLanguage} → ${output.targetLanguage}: '
                    '${output.translatedText}',
                    name: 'TranslationWidget',
                  );
                },
                error: (err, st) {
                  log(err.toString(), name: 'TranslationWidget:error');
                },
                loading: () {
                  log('Translating…', name: 'TranslationWidget');
                },
              );
            },
            child: const Text('Translate'),
          ),
        ],
      ),
    );
  }
}
