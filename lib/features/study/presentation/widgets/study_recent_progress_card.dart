import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/widgets/peruse_sheet_card.dart';
import 'package:peruse/features/study/presentation/controller/study_metrics_providers.dart';

class StudyRecentProgressCard extends ConsumerWidget {
  const StudyRecentProgressCard({
    super.key,
    this.dailyGoalTarget = 20,
  });

  final int dailyGoalTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authRepositoryProvider).currentUser?.id;
    if (userId == null) {
      return _EmptyRecentProgressCard();
    }

    final progressAsync = ref.watch(
      dailyGoalProgressProvider(
        DailyGoalParams(
          userId: userId,
          date: DateTime.now(),
          dailyGoalTarget: dailyGoalTarget,
        ),
      ),
    );
    final statsAsync = ref.watch(userGlobalStatsProvider(userId));

    return PeruseSheetCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Recent Progress',
            style: context.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Keep the momentum going to reach your conversational badge.',
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          statsAsync.when(
            data: (stats) => Row(
              children: [
                Expanded(
                  child: _ProgressStat(
                    label: 'Streak',
                    value: '${stats.currentStreak} Days',
                    icon: Icons.local_fire_department,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _ProgressStat(
                    label: 'Today',
                    value: '${stats.wordsStudiedToday} Words',
                    icon: Icons.auto_graph,
                    color: const Color(0xFF1E5EFF),
                  ),
                ),
              ],
            ),
            loading: () => const _StatsLoading(),
            error: (error, stackTrace) => _StatsError(message: '$error'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: progressAsync.when(
              data: (progress) => _GoalRing(progress: progress),
              loading: () => const _GoalRing(progress: 0.0, isLoading: true),
              error: (error, stackTrace) => const _GoalRing(progress: 0.0),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecentProgressCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PeruseSheetCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppRadius.xxl,
      child: Text(
        'Sign in to track your progress.',
        style: context.textTheme.bodyMedium,
      ),
    );
  }
}

class _StatsLoading extends StatelessWidget {
  const _StatsLoading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _StatSkeleton()),
        SizedBox(width: AppSpacing.md),
        Expanded(child: _StatSkeleton()),
      ],
    );
  }
}

class _StatsError extends StatelessWidget {
  const _StatsError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Progress unavailable: $message',
      style: context.textTheme.bodyMedium,
    );
  }
}

class _StatSkeleton extends StatelessWidget {
  const _StatSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: context.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                label.toUpperCase(),
                style: context.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalRing extends StatelessWidget {
  const _GoalRing({
    required this.progress,
    this.isLoading = false,
  });

  final double progress;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    final value = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -math.pi / 2,
            child: SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: isLoading ? null : value,
                strokeWidth: 10,
                backgroundColor: AppColors.neutralOutline,
                color: AppColors.primary,
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(value * 100).round()}%',
                style: context.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'DAILY GOAL',
                style: context.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
