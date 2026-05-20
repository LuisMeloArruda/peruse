import 'package:flutter/material.dart';

import 'package:peruse/core/theme/theme.dart';

/// Horizontal progress bar with a trailing percentage label.
class PeruseLinearProgress extends StatelessWidget {
  const PeruseLinearProgress({super.key, required this.progress, this.color});

  /// 0–1; shown as a bar and trailing label.
  final double progress;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    final accentColor = color ?? AppColors.primary;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: AppColors.neutralOutline,
              color: accentColor,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${(value * 100).round()}%',
          style: context.textTheme.labelLarge?.copyWith(color: accentColor),
        ),
      ],
    );
  }
}
