import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:peruse/core/theme/theme.dart';

class StudySessionScreen extends StatelessWidget {
  const StudySessionScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppColors.brandTitle,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Study Session',
                style: context.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'We are preparing the study experience for this deck.',
                style: context.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              PeruseStatusTile(
                title: 'Deck ID',
                value: deckId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PeruseStatusTile extends StatelessWidget {
  const PeruseStatusTile({super.key, required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: context.textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(value, style: context.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
