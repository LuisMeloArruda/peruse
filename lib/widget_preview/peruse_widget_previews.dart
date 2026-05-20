import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/widgets/peruse_deck_list_tile.dart';
import 'package:peruse/core/widgets/peruse_hero_heading.dart';
import 'package:peruse/core/widgets/peruse_linear_progress.dart';
import 'package:peruse/core/widgets/peruse_pill_toggle.dart';
import 'package:peruse/core/widgets/peruse_section_header.dart';
import 'package:peruse/core/widgets/peruse_sheet_card.dart';
import 'package:peruse/core/widgets/peruse_stat_bento_card.dart';
import 'package:peruse/core/widgets/peruse_text_field.dart';

/// Material theme for the Widget Previewer ([AppTheme.light]).
PreviewThemeData perusePreviewTheme() {
  return PreviewThemeData(materialLight: AppTheme.light());
}

@Preview(
  name: 'Peruse widget catalog',
  group: 'Peruse',
  theme: perusePreviewTheme,
  size: Size(390, 1200),
)
Widget previewPeruseWidgetCatalog() {
  return const _PeruseCatalogBody();
}

class _PeruseCatalogBody extends StatefulWidget {
  const _PeruseCatalogBody();

  @override
  State<_PeruseCatalogBody> createState() => _PeruseCatalogBodyState();
}

class _PeruseCatalogBodyState extends State<_PeruseCatalogBody> {
  bool _weekSelected = true;
  final _sampleController = TextEditingController(text: 'Sample text');

  @override
  void dispose() {
    _sampleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _PreviewSectionLabel('PeruseHeroHeading'),
          const PeruseHeroHeading(
            title: 'Growth',
            subtitle: 'Your linguistic evolution, quantified.',
          ),
          const SizedBox(height: AppSpacing.xl),
          _PreviewSectionLabel('PeruseTextField'),
          PeruseTextField(
            controller: _sampleController,
            labelText: 'Full name',
            hintText: 'Alex Rivers',
            prefixIcon: Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.formFieldGap),
          PeruseTextField(
            key: const ValueKey('preview-password'),
            labelText: 'Password',
            hintText: '••••••••',
            obscureText: true,
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _PreviewSectionLabel('PeruseStatBentoCard'),
          PeruseStatBentoCard(
            variant: PeruseStatBentoVariant.muted,
            leading: Icon(Icons.stacked_bar_chart, color: AppColors.primary),
            badge: '+12 today',
            value: '1,482',
            label: 'Total words',
          ),
          const SizedBox(height: AppSpacing.md),
          PeruseStatBentoCard(
            variant: PeruseStatBentoVariant.primary,
            leading: Icon(
              Icons.local_fire_department,
              color: AppColors.onPrimarySoft,
            ),
            value: '24 Days',
            label: 'Daily streak',
          ),
          const SizedBox(height: AppSpacing.md),
          const PeruseStatBentoCard(
            variant: PeruseStatBentoVariant.elevated,
            leading: Icon(Icons.track_changes, color: AppColors.primary),
            value: '94.8%',
            label: 'Avg. accuracy',
          ),
          const SizedBox(height: AppSpacing.xl),
          _PreviewSectionLabel('PerusePillToggle'),
          PerusePillToggle(
            leftLabel: 'Week',
            rightLabel: 'Month',
            leftSelected: _weekSelected,
            onChanged: (left) => setState(() => _weekSelected = left),
          ),
          const SizedBox(height: AppSpacing.xl),
          _PreviewSectionLabel('PeruseSheetCard + PeruseSectionHeader'),
          PeruseSheetCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PeruseSectionHeader(
                  title: 'Learning velocity',
                  trailing: PerusePillToggle(
                    leftLabel: 'Week',
                    rightLabel: 'Month',
                    leftSelected: true,
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    'Chart placeholder',
                    style: context.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _PreviewSectionLabel('PeruseLinearProgress'),
          const PeruseLinearProgress(progress: 0.68),
          const SizedBox(height: AppSpacing.md),
          const PeruseLinearProgress(
            progress: 0.32,
            color: AppColors.brandTitle,
          ),
          const SizedBox(height: AppSpacing.xl),
          _PreviewSectionLabel('PeruseDeckListTile'),
          PeruseDeckListTile(
            title: 'Business Mandarin',
            subtitle: '240 Words • Level B2',
            progress: 0.75,
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.md),
          PeruseDeckListTile(
            title: 'Parisian Slang',
            subtitle: '88 Words • Level C1',
            progress: 0.30,
            progressColor: AppColors.brandTitle,
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _PreviewSectionLabel extends StatelessWidget {
  const _PreviewSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: context.textTheme.labelMedium?.copyWith(
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
