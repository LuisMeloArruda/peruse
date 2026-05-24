import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/theme/app_radius.dart';
import 'package:peruse/features/auth/presentation/controller/auth_notifier.dart';
import 'package:peruse/features/auth/domain/entities/app_user.dart';
import 'package:peruse/features/profile/domain/entities/user_profile.dart';
import 'package:peruse/features/profile/domain/profile_languages.dart';
import 'package:peruse/features/profile/presentation/controller/profile_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAction = ref.watch(authControllerProvider);
    final profileState = ref.watch(profileProvider);
    final user = ref.watch(authStateProvider).asData?.value;
    final profile = profileState.asData?.value;
    final isBusy = authAction.isLoading || profileState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
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
                  if (value == null || value == profile?.preferredLanguage) {
                    return;
                  }
                  ref
                      .read(profileProvider.notifier)
                      .updatePreferredLanguage(value);
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
    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? 'No email available';
    final languageLabel = profile == null
        ? 'Loading language preference...'
        : profileLanguageLabel(profile!.preferredLanguage);
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P';

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
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                      Text(email, style: Theme.of(context).textTheme.bodyMedium),
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
                    'Preferred language',
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
  final ValueChanged<String?> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final selectedLanguage = profile?.preferredLanguage ?? 'en';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Language preference',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the interface language you want to use in the app.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              value: selectedLanguage,
              onChanged: isBusy ? null : onLanguageChanged,
              decoration: const InputDecoration(
                labelText: 'Preferred language',
              ),
              items: supportedProfileLanguageCodes
                  .map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(profileLanguageLabel(code)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This preference is stored locally and synced to your account.',
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
        ? 'Signed in account details will appear here.'
        : 'Manage your session and leave the account when you are done.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isBusy ? null : onLogout,
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
