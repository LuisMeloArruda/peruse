import 'package:flutter/material.dart';

import 'package:peruse/core/theme/theme.dart';

/// Two-option pill control (Figma WEEK / MONTH). For more options, use [PerusePillToggle.index].
class PerusePillToggle extends StatelessWidget {
  const PerusePillToggle({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftSelected,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final bool leftSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pill(
          label: leftLabel,
          selected: leftSelected,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: AppSpacing.xs),
        _Pill(
          label: rightLabel,
          selected: !leftSelected,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = selected
        ? context.textTheme.labelSmall?.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          )
        : context.textTheme.labelSmall?.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.2,
          );

    return Material(
      color: selected ? AppColors.neutralOutline : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          child: Text(label.toUpperCase(), style: textStyle),
        ),
      ),
    );
  }
}
