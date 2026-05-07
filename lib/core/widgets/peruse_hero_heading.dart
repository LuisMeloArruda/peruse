import 'package:flutter/material.dart';

import 'package:peruse/core/theme/theme.dart';

/// Large display title + optional subtitle (Figma “Growth” hero block).
class PeruseHeroHeading extends StatelessWidget {
  const PeruseHeroHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.textAlign = TextAlign.start,
  });

  final String title;
  final String? subtitle;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: context.textTheme.displayLarge,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            textAlign: textAlign,
            style: context.textTheme.bodyLarge,
          ),
        ],
      ],
    );
  }
}
