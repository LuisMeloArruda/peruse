import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:peruse/core/theme/theme.dart';

/// Deck row: circular progress, title, subtitle, chevron — matches “Deck Card” in Figma.
class PeruseDeckListTile extends StatelessWidget {
  const PeruseDeckListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    this.progressColor,
    this.onTap,
  });

  final String title;
  final String subtitle;

  /// 0–1; shown as a ring and center label.
  final double progress;
  final Color? progressColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ringColor = progressColor ?? AppColors.primary;

    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              _RingProgress(
                progress: progress.clamp(0, 1),
                color: ringColor,
                label: '${(progress.clamp(0, 1) * 100).round()}%',
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: context.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingProgress extends StatelessWidget {
  const _RingProgress({
    required this.progress,
    required this.color,
    required this.label,
  });

  final double progress;
  final Color color;
  final String label;

  static const double _size = 64;
  static const double _stroke = 5;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -math.pi / 2,
            child: SizedBox(
              width: _size,
              height: _size,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: _stroke,
                backgroundColor: AppColors.neutralOutline,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              height: 15 / 10,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
