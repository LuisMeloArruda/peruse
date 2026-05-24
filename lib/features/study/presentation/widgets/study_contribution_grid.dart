import 'package:flutter/material.dart';

import 'package:peruse/core/theme/theme.dart';

class StudyContributionGrid extends StatelessWidget {
  const StudyContributionGrid({
    super.key,
    required this.contributions,
  });

  final Map<DateTime, int> contributions;

  @override
  Widget build(BuildContext context) {
    const columns = 12;
    const rows = 7;
    const cellSize = 18.0;
    const spacing = 6.0;

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 83));
    final dates = List<DateTime>.generate(
      columns * rows,
      (index) => start.add(Duration(days: index)),
    );

    final gridWidth = (cellSize * columns) + (spacing * (columns - 1));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: gridWidth,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: dates.length,
          itemBuilder: (context, index) {
            final date = dates[index];
            final normalized = DateTime(date.year, date.month, date.day);
            final count = contributions[normalized] ?? 0;

            return Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: _colorFor(count),
                borderRadius: BorderRadius.circular(5),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _colorFor(int count) {
    if (count <= 0) return AppColors.heatmapEmpty;
    if (count <= 5) return AppColors.primary.withValues(alpha: 0.25);
    if (count <= 10) return AppColors.primary.withValues(alpha: 0.6);
    return AppColors.primary;
  }
}
