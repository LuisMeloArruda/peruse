import 'package:flutter/material.dart';

import 'package:peruse/core/theme/theme.dart';

/// Bento stat tile variants from the Growth screen (muted grey, green streak, white elevated).
enum PeruseStatBentoVariant { muted, primary, elevated }

class PeruseStatBentoCard extends StatelessWidget {
  const PeruseStatBentoCard({
    super.key,
    required this.value,
    required this.label,
    this.variant = PeruseStatBentoVariant.muted,
    this.leading,
    this.badge,
    this.minHeight = 192,
  });

  final String value;
  final String label;
  final PeruseStatBentoVariant variant;
  final Widget? leading;
  final String? badge;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == PeruseStatBentoVariant.primary;
    final isElevated = variant == PeruseStatBentoVariant.elevated;

    final bg = switch (variant) {
      PeruseStatBentoVariant.muted => AppColors.surfaceMuted,
      PeruseStatBentoVariant.primary => AppColors.primary,
      PeruseStatBentoVariant.elevated => AppColors.surfaceContainer,
    };

    final valueStyle = context.textTheme.headlineSmall?.copyWith(
      color: isPrimary ? AppColors.onPrimarySoft : AppColors.onSurface,
    );
    final labelStyle = context.textTheme.titleSmall?.copyWith(
      color: isPrimary
          ? AppColors.onPrimarySoft.withValues(alpha: 0.8)
          : AppColors.onSurfaceVariant,
      fontWeight: FontWeight.w400,
    );
    final badgeStyle = context.textTheme.labelSmall?.copyWith(
      color: isPrimary ? AppColors.onPrimarySoft : AppColors.onSurfaceVariant,
      letterSpacing: 0.6,
    );

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: isPrimary
            ? const [
                BoxShadow(
                  color: Color(0x26006A28),
                  blurRadius: 40,
                  offset: Offset(0, 20),
                ),
              ]
            : isElevated
            ? const [
                BoxShadow(
                  color: Color(0x0F2C2F2F),
                  blurRadius: 40,
                  offset: Offset(0, 20),
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (leading != null || badge != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading ?? const SizedBox.shrink(),
                if (badge != null)
                  Text(badge!.toUpperCase(), style: badgeStyle)
                else
                  const SizedBox.shrink(),
              ],
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: valueStyle),
              const SizedBox(height: AppSpacing.xxs),
              Text(label.toUpperCase(), style: labelStyle),
            ],
          ),
        ],
      ),
    );
  }
}
