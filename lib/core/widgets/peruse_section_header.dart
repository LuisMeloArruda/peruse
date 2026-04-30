import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Section title row (e.g. “Curated Decks”) with optional trailing control.
class PeruseSectionHeader extends StatelessWidget {
  const PeruseSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final String title;
  final Widget? trailing;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.headlineMedium;

    if (trailing == null) {
      return Text(title, style: style);
    }

    return Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Expanded(child: Text(title, style: style)),
        const SizedBox(width: AppSpacing.sm),
        trailing!,
      ],
    );
  }
}
