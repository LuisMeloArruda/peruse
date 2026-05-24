import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/widgets/peruse_section_header.dart';
import 'package:peruse/core/widgets/peruse_sheet_card.dart';
import 'package:peruse/core/widgets/peruse_stat_bento_card.dart';
import 'package:peruse/features/study/presentation/controller/study_metrics_providers.dart';
import 'package:peruse/features/study/presentation/widgets/study_contribution_grid.dart';

class GrowthScreen extends ConsumerWidget {
  const GrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authRepositoryProvider).currentUser?.id;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: userId == null
              ? Center(
                  child: Text(
                    'Sign in to view growth insights.',
                    style: context.textTheme.bodyMedium,
                  ),
                )
              : ListView(
                  children: [
                    Text('Growth', style: context.textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.lg),
                    PeruseSectionHeader(
                      title: 'Stats',
                      trailing: Text(
                        'Last 12 weeks',
                        style: context.textTheme.labelSmall,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ref.watch(userGlobalStatsProvider(userId)).when(
                          data: (stats) => Row(
                            children: [
                              Expanded(
                                child: PeruseStatBentoCard(
                                  value: '${stats.currentStreak}',
                                  label: 'Streak Days',
                                  variant: PeruseStatBentoVariant.primary,
                                  leading: const Icon(
                                    Icons.local_fire_department,
                                    color: AppColors.onPrimarySoft,
                                  ),
                                  minHeight: 120,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: PeruseStatBentoCard(
                                  value: '${stats.lifetimeAccuracy.toStringAsFixed(1)}%',
                                  label: 'Avg. Accuracy',
                                  variant: PeruseStatBentoVariant.elevated,
                                  leading: const Icon(
                                    Icons.track_changes,
                                    color: AppColors.primary,
                                  ),
                                  minHeight: 120,
                                ),
                              ),
                            ],
                          ),
                          loading: () => const _StatsSkeletonRow(),
                          error: (error, stackTrace) => Text(
                            'Stats unavailable: $error',
                            style: context.textTheme.bodyMedium,
                          ),
                        ),
                    const SizedBox(height: AppSpacing.xl),
                    const PeruseSectionHeader(title: 'Learning Consistency'),
                    const SizedBox(height: AppSpacing.md),
                    PeruseSheetCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      radius: AppRadius.xxl,
                      child: ref.watch(contributionGridProvider(userId)).when(
                            data: (grid) => StudyContributionGrid(
                              contributions: grid,
                            ),
                            loading: () => const _GridSkeleton(),
                            error: (error, stackTrace) => Text(
                              'Grid unavailable: $error',
                              style: context.textTheme.bodyMedium,
                            ),
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatsSkeletonRow extends StatelessWidget {
  const _StatsSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SkeletonBlock(height: 120)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _SkeletonBlock(height: 120)),
      ],
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return _SkeletonBlock(height: 140);
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    );
  }
}
