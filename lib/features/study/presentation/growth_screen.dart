import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peruse/core/di/providers.dart';
import 'package:peruse/core/localization/locale_ext.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/widgets/peruse_deck_list_tile.dart';
import 'package:peruse/core/widgets/peruse_hero_heading.dart';
import 'package:peruse/core/widgets/peruse_pill_toggle.dart';
import 'package:peruse/core/widgets/peruse_section_header.dart';
import 'package:peruse/core/widgets/peruse_sheet_card.dart';
import 'package:peruse/core/widgets/peruse_stat_bento_card.dart';
import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/features/decks/domain/entities/deck.dart';
import 'package:peruse/features/decks/domain/entities/word.dart';
import 'package:peruse/features/study/data/models/deck_mastery_stats.dart';
import 'package:peruse/features/study/presentation/controller/study_focus_provider.dart';
import 'package:peruse/features/study/presentation/controller/study_metrics_providers.dart';
import 'package:peruse/features/study/presentation/widgets/study_contribution_grid.dart';

class GrowthScreen extends ConsumerStatefulWidget {
  const GrowthScreen({super.key});

  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen> {
  bool _isWeekly = true;

  String _formatAccuracy(double accuracy) {
    final normalized = accuracy > 1 ? accuracy / 100 : accuracy;
    return '${(normalized.clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
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
                    context.translate('sign_in_for_growth'),
                    style: context.textTheme.bodyMedium,
                  ),
                )
              : ListView(
                  children: [
                    PeruseHeroHeading(
                      title: context.translate('growth_title'),
                      subtitle: context.translate('growth_subtitle'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ref.watch(userGlobalStatsProvider(userId)).when(
                          data: (stats) => Column(
                            children: [
                              PeruseStatBentoCard(
                                value: context.translate(
                                  'daily_streak_days',
                                  args: {'days': '${stats.currentStreak}'},
                                ),
                                label: context.translate('daily_streak'),
                                variant: PeruseStatBentoVariant.primary,
                                leading: const Icon(
                                  Icons.local_fire_department,
                                  color: AppColors.onPrimarySoft,
                                ),
                                minHeight: 140,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              PeruseStatBentoCard(
                                value: _formatAccuracy(
                                  stats.lifetimeAccuracy,
                                ),
                                label: context.translate('avg_accuracy'),
                                variant: PeruseStatBentoVariant.elevated,
                                leading: const Icon(
                                  Icons.verified_rounded,
                                  color: AppColors.primary,
                                ),
                                minHeight: 140,
                              ),
                            ],
                          ),
                          loading: () => const _StatsSkeletonRow(),
                          error: (error, stackTrace) => Text(
                            context.translate(
                              'stats_unavailable',
                              args: {'error': '$error'},
                            ),
                            style: context.textTheme.bodyMedium,
                          ),
                        ),
                    const SizedBox(height: AppSpacing.xl),
                    PeruseSectionHeader(
                      title: context.translate('learning_velocity'),
                      trailing: PerusePillToggle(
                        leftLabel: context.translate('week'),
                        rightLabel: context.translate('month'),
                        leftSelected: _isWeekly,
                        onChanged: (value) {
                          setState(() {
                            _isWeekly = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PeruseSheetCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      radius: AppRadius.xxl,
                      child: _VelocityChart(
                        isWeekly: _isWeekly,
                        weekly: ref.watch(weeklyVelocityProvider(userId)),
                        monthly: ref.watch(monthlyVelocityProvider(userId)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PeruseSectionHeader(
                      title: context.translate('curated_decks'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                      ref.watch(studyDecksProvider).when(
                        data: (decks) => _DeckProgressList(
                          decks: decks,
                          userId: userId,
                        ),
                          loading: () => const _DecksSkeleton(),
                          error: (error, stackTrace) => Text(
                            context.translate(
                              'decks_unavailable',
                              args: {'message': '$error'},
                            ),
                            style: context.textTheme.bodyMedium,
                          ),
                        ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.translate('learning_consistency'),
                            style: context.textTheme.headlineMedium,
                          ),
                        ),
                        _HeatmapLegend(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PeruseSheetCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      radius: AppRadius.xxl,
                      child: ref.watch(contributionGridProvider(userId)).when(
                            data: (grid) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.translate('activity_last_12_weeks'),
                                  style: context.textTheme.labelSmall?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                StudyContributionGrid(contributions: grid),
                              ],
                            ),
                            loading: () => const _GridSkeleton(),
                            error: (error, stackTrace) => Text(
                              context.translate(
                                'grid_unavailable',
                                args: {'error': '$error'},
                              ),
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

class _VelocityChart extends StatelessWidget {
  const _VelocityChart({
    required this.isWeekly,
    required this.weekly,
    required this.monthly,
  });

  final bool isWeekly;
  final AsyncValue<List<LocalDailyProgress>> weekly;
  final AsyncValue<List<LocalDailyProgress>> monthly;

  static const double _yAxisWidth = 36;

  static const _weekdayKeys = [
    'weekday_mon',
    'weekday_tue',
    'weekday_wed',
    'weekday_thu',
    'weekday_fri',
    'weekday_sat',
    'weekday_sun',
  ];

  @override
  Widget build(BuildContext context) {
    final value = isWeekly ? weekly : monthly;

    return value.when(
      data: (rows) {
        final points = isWeekly
            ? _buildWeekSeries(rows)
            : _buildMonthSeries(rows);
        final maxValue = points.isEmpty ? 0.0 : points.reduce(math.max);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isWeekly
                  ? context.translate('this_week')
                  : context.translate('last_30_days'),
              style: context.textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.translate('words_studied_per_day'),
                  style: context.textTheme.titleSmall,
                ),
                Text(
                  context.translate(
                    'avg_per_day',
                    args: {'average': _average(points).toStringAsFixed(1)},
                  ),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VelocityYAxis(
                    maxValue: maxValue <= 0 ? 1 : maxValue,
                    width: _yAxisWidth,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: CustomPaint(
                      painter: _VelocityPainter(
                        values: points,
                        maxValue: maxValue <= 0 ? 1 : maxValue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(
                left: _yAxisWidth + AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _labelsForRange(context, isWeekly)
                    .map(
                      (label) => Text(
                        label,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const _ChartSkeleton(),
      error: (error, stackTrace) => Text(
        context.translate(
          'velocity_unavailable',
          args: {'error': '$error'},
        ),
        style: context.textTheme.bodyMedium,
      ),
    );
  }

  List<String> _labelsForRange(BuildContext context, bool weekly) {
    if (weekly) {
      return _weekdayKeys.map(context.translate).toList();
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(
      const Duration(days: 29),
    );
    const ticks = [0, 6, 12, 18, 24, 29];
    return ticks.map((offset) {
      final date = start.add(Duration(days: offset));
      return '${date.month}/${date.day}';
    }).toList();
  }

  List<double> _buildWeekSeries(List<LocalDailyProgress> rows) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final lookup = _toDateMap(rows);

    return List<double>.generate(7, (index) {
      final date = start.add(Duration(days: index));
      final normalized = DateTime(date.year, date.month, date.day);
      return (lookup[normalized] ?? 0).toDouble();
    });
  }

  List<double> _buildMonthSeries(List<LocalDailyProgress> rows) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 29));
    final lookup = _toDateMap(rows);

    return List<double>.generate(30, (index) {
      final date = start.add(Duration(days: index));
      final normalized = DateTime(date.year, date.month, date.day);
      return (lookup[normalized] ?? 0).toDouble();
    });
  }

  Map<DateTime, int> _toDateMap(List<LocalDailyProgress> rows) {
    final map = <DateTime, int>{};
    for (final row in rows) {
      final parsed = _parseDateKey(row.date);
      final normalized = DateTime(parsed.year, parsed.month, parsed.day);
      map[normalized] = row.wordsStudied;
    }
    return map;
  }

  DateTime _parseDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    return total / values.length;
  }
}

class _VelocityPainter extends CustomPainter {
  _VelocityPainter({required this.values, required this.maxValue});

  final List<double> values;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final linePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.22),
          AppColors.primary.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final step = values.length == 1 ? size.width : size.width / (values.length - 1);
    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < values.length; i++) {
      final x = step * i;
      final normalized = (values[i] / maxValue).clamp(0.0, 1.0);
      final y = size.height - (normalized * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _VelocityPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.maxValue != maxValue;
  }
}

class _VelocityYAxis extends StatelessWidget {
  const _VelocityYAxis({required this.maxValue, required this.width});

  final double maxValue;
  final double width;

  @override
  Widget build(BuildContext context) {
    final ticks = _buildTicks(maxValue);

    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: ticks
            .map(
              (value) => Text(
                value.toStringAsFixed(0),
                style: context.textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  List<double> _buildTicks(double max) {
    final roundedMax = max <= 1 ? 1 : max.ceilToDouble();
    return <double>[
      roundedMax.toDouble(), 
      (roundedMax * 0.66), 
      (roundedMax * 0.33), 
      0.0,
    ];
  }
}

class _DeckProgressList extends StatelessWidget {
  const _DeckProgressList({required this.decks, required this.userId});

  final List<AppDeck> decks;
  final String userId;

  @override
  Widget build(BuildContext context) {
    if (decks.isEmpty) {
      return Text(
        context.translate('no_decks_track_progress'),
        style: context.textTheme.bodyMedium,
      );
    }

    return Column(
      children: [
        for (var i = 0; i < decks.length; i++) ...[
          _DeckProgressTile(deck: decks[i], userId: userId),
          if (i < decks.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _DeckProgressTile extends ConsumerWidget {
  const _DeckProgressTile({required this.deck, required this.userId});

  final AppDeck deck;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordsState = ref.watch(deckWordsProvider(deck.id));
    final masteryState = ref.watch(
      deckMasteryProvider(
        DeckMasteryParams(userId: userId, deckId: deck.id),
      ),
    );

    return wordsState.when(
      data: (words) => masteryState.when(
        data: (mastery) {
          final summary = _summarizeDeck(context, words, mastery);
          return PeruseDeckListTile(
            title: deck.name,
            subtitle: context.translate(
              'deck_progress_subtitle',
              args: {
                'wordCount': '${summary.totalWords}',
                'level': summary.difficultyLabel,
              },
            ),
            progress: summary.progress,
          );
        },
        loading: () => const _SkeletonBlock(height: 90),
        error: (error, stackTrace) => Text(
          context.translate(
            'deck_unavailable',
            args: {'error': '$error'},
          ),
          style: context.textTheme.bodyMedium,
        ),
      ),
      loading: () => const _SkeletonBlock(height: 90),
      error: (error, stackTrace) => Text(
        context.translate(
          'deck_unavailable',
          args: {'error': '$error'},
        ),
        style: context.textTheme.bodyMedium,
      ),
    );
  }

  _DeckSummary _summarizeDeck(
    BuildContext context,
    List<AppWord> words,
    DeckMasteryStats mastery,
  ) {
    final totalWords = words.length;
    final hasData = mastery.totalAnswers > 0;
    final accuracy = mastery.accuracy.clamp(0.0, 1.0);

    return _DeckSummary(
      progress: hasData ? accuracy : 0,
      totalWords: totalWords,
      difficultyLabel: hasData
          ? _difficultyLabel(context, accuracy)
          : context.translate('no_data'),
    );
  }

  String _difficultyLabel(BuildContext context, double accuracy) {
    if (accuracy < 0.2) return context.translate('level_a1');
    if (accuracy < 0.4) return context.translate('level_a2');
    if (accuracy < 0.65) return context.translate('level_b1');
    if (accuracy < 0.85) return context.translate('level_b2');
    if (accuracy < 0.95) return context.translate('level_c1');
    return context.translate('level_c2');
  }
}

class _DeckSummary {
  const _DeckSummary({
    required this.progress,
    required this.totalWords,
    required this.difficultyLabel,
  });

  final double progress;
  final int totalWords;
  final String difficultyLabel;
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

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _SkeletonBlock(height: 180);
  }
}

class _DecksSkeleton extends StatelessWidget {
  const _DecksSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SkeletonBlock(height: 90),
        SizedBox(height: AppSpacing.md),
        _SkeletonBlock(height: 90),
      ],
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final entries = [
      _HeatmapLegendEntry(
        AppColors.heatmapEmpty,
        context.translate('heatmap_0'),
      ),
      _HeatmapLegendEntry(
        AppColors.primary.withValues(alpha: 0.25),
        context.translate('heatmap_1_5'),
      ),
      _HeatmapLegendEntry(
        AppColors.primary.withValues(alpha: 0.6),
        context.translate('heatmap_6_10'),
      ),
      _HeatmapLegendEntry(
        AppColors.primary,
        context.translate('heatmap_11_plus'),
      ),
    ];

    return Row(
      children: [
        Text(
          context.translate('heatmap_less'),
          style: context.textTheme.labelSmall,
        ),
        const SizedBox(width: AppSpacing.xs),
        for (final entry in entries) ...[
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: entry.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.label,
                style: context.textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
        Text(
          context.translate('heatmap_more'),
          style: context.textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _HeatmapLegendEntry {
  const _HeatmapLegendEntry(this.color, this.label);

  final Color color;
  final String label;
}
