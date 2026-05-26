import 'package:flutter/material.dart';
import 'package:peruse/core/localization/app_base_translations.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/utils/assets.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({
    super.key,
    this.error,
    this.onRetry,
  });

  final Object? error;
  final VoidCallback? onRetry;

  bool get _hasError => error != null;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Image.asset(
                    kAppIconAsset,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  appBaseTranslations['app_title']!,
                  style: textTheme.headlineSmall?.copyWith(
                    color: AppColors.brandTitle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                 Text(
                    'Initialising transalation service ...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.brandTitle,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: AppSpacing.xxl),
                if (_hasError) ...[
                  Text(
                    appBaseTranslations['splash_translations_error']!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (onRetry != null)
                    FilledButton(
                      onPressed: onRetry,
                      child: Text(appBaseTranslations['try_again']!),
                    ),
                ] else
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
