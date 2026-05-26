import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localization_agent/flutter_localization_agent.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:peruse/core/localization/locale_ext.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/features/auth/presentation/controller/auth_notifier.dart';
import 'package:peruse/features/auth/domain/entities/app_user.dart';
import 'package:peruse/features/profile/domain/entities/user_profile.dart';
import 'package:peruse/features/profile/domain/profile_languages.dart';
import 'package:peruse/features/profile/presentation/controller/profile_notifier.dart';

class ProfileScreen extends HookConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAction = ref.watch(authControllerProvider);
    final profileState = ref.watch(profileProvider);
    final user = ref.watch(authStateProvider).asData?.value;
    final profile = profileState.asData?.value;
    final chanagingLang = useState<bool>(true);
    final isBusy =
        authAction.isLoading || profileState.isLoading || chanagingLang.value;

    return Scaffold(
      appBar: AppBar(title: Text(context.translate('profile_title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHeaderCard(user: user, profile: profile),
              const SizedBox(height: AppSpacing.lg),
              _LanguageCard(
                profile: profile,
                isBusy: isBusy,
                onLanguageChanged: (value) {
                  if (value == null ||
                      value == context.translationService.currentLanguage) {
                    return;
                  }
                  chanagingLang.value = true;
                  context.translationService
                      .changeLanguage(value)
                      .then((_) {
                        ref
                            .read(profileProvider.notifier)
                            .updatePreferredLanguage(value.code);
                      })
                      .whenComplete(() => chanagingLang.value = false);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _AccountCard(
                user: user,
                isBusy: authAction.isLoading,
                onLogout: authAction.isLoading
                    ? null
                    : () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({this.user, this.profile});

  final AppUser? user;
  final AppUserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? context.translate('user_fallback');
    final email = user?.email ?? context.translate('no_email_available');
    final languageLabel = profile == null
        ? context.translate('loading_language_preference')
        : context.translate(
            profileLanguageTranslationKey(
              context.translationService.currentLanguage.code,
            ),
          );
    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'P';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(
                    initials,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.translate('preferred_language'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    languageLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.profile,
    required this.isBusy,
    required this.onLanguageChanged,
  });

  final AppUserProfile? profile;
  final bool isBusy;
  final ValueChanged<Language?> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final selectedLanguage = context.translationService.currentLanguage;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.translate('language_preference_title'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              context.translate('language_preference_description'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (isBusy)
              Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<Language>(
                initialValue: selectedLanguage,

                onChanged: isBusy ? null : onLanguageChanged,
                decoration: InputDecoration(
                  labelText: context.translate('preferred_language'),
                ),
                items: context.translationService.supportedLanguages
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry,
                        child: Text(
                          context.translate(
                            profileLanguageTranslationKey(entry.code),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.translate('language_preference_sync_note'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.user,
    required this.isBusy,
    required this.onLogout,
  });

  final AppUser? user;
  final bool isBusy;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final subtitle = user == null
        ? context.translate('account_signed_out_subtitle')
        : context.translate('account_signed_in_subtitle');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.translate('account_title'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isBusy ? null : onLogout,
                child: Text(context.translate('logout')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
