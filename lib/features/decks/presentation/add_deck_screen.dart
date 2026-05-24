import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:peruse/core/theme/theme.dart';
import 'package:peruse/core/widgets/peruse_text_field.dart';
import 'package:peruse/features/decks/presentation/controller/decks_notifier.dart';

class AddDeckScreen extends ConsumerStatefulWidget {
  const AddDeckScreen({super.key});

  @override
  ConsumerState<AddDeckScreen> createState() => _AddDeckScreenState();
}

class _AddDeckScreenState extends ConsumerState<AddDeckScreen> {
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

  String? _coverImagePath;
  int _selectedColorIndex = 0;
  int _selectedIconIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final permission = await Permission.photos.request();
    if (!permission.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allow photo library access to choose a deck cover.'),
          ),
        );
      }
      return;
    }

    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (!mounted || image == null) {
      return;
    }

    setState(() {
      _coverImagePath = image.path;
    });
  }

  Future<void> _saveDeck() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      debugPrint('Deck name is required.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a deck name.')),
      );
      return;
    }

    final color = _colorOptions[_selectedColorIndex].value;
    final icon = _iconOptions[_selectedIconIndex].key;

    await ref
        .read(decksProvider.notifier)
        .createDeck(
          name: name,
          bio: _bioController.text.trim(),
          color: color,
          icon: icon,
          coverImageUrl: _coverImagePath,
        );

    if (mounted) {
      context.pop();
    }
  }

  void _discardDraft() {
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopBar(onBack: () => context.pop()),
              const SizedBox(height: AppSpacing.lg),
              _HeaderTitle(),
              const SizedBox(height: AppSpacing.xl),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PeruseTextField(
                      controller: _nameController,
                      labelText: 'Deck name',
                      hintText: 'e.g. Italian Gastronomy',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'VISUAL ANCHOR',
                      style: context.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: List.generate(_colorOptions.length, (index) {
                        final option = _colorOptions[index];
                        final isSelected = _selectedColorIndex == index;
                        return _ColorDot(
                          color: option.color,
                          isSelected: isSelected,
                          onTap: () => setState(() {
                            _selectedColorIndex = index;
                          }),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _iconOptions.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 1,
                          ),
                      itemBuilder: (context, index) {
                        final option = _iconOptions[index];
                        final isSelected = _selectedIconIndex == index;
                        return _IconTile(
                          icon: option.icon,
                          isSelected: isSelected,
                          onTap: () => setState(() {
                            _selectedIconIndex = index;
                          }),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionCard(
                child: PeruseTextField(
                  controller: _bioController,
                  labelText: 'Short bio',
                  hintText: 'What will you master today?',
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deck cover',
                      style: context.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CoverImageCard(
                      imagePath: _coverImagePath,
                      onTap: _pickCoverImage,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: _saveDeck,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: const StadiumBorder(),
                  textStyle: context.textTheme.titleMedium,
                ),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Save Deck'),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: _discardDraft,
                  child: Text(
                    'Discard draft'.toUpperCase(),
                    style: context.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.brandTitle,
        ),
        Expanded(
          child: Text(
            'Peruse',
            style: context.textTheme.titleLarge?.copyWith(
              color: AppColors.brandTitle,
            ),
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.primary, width: 2),
          ),
          child: const Icon(
            Icons.person_rounded,
            size: 20,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final titleStyle = context.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CURATION',
          style: context.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.8,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        RichText(
          text: TextSpan(
            style: titleStyle,
            children: [
              const TextSpan(text: 'Create your\n'),
              TextSpan(
                text: 'knowledge\n',
                style: titleStyle?.copyWith(color: AppColors.link),
              ),
              const TextSpan(text: 'deck.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: child,
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Icon(icon, color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _CoverImageCard extends StatelessWidget {
  const _CoverImageCard({required this.imagePath, required this.onTap});

  final String? imagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          color: AppColors.surfaceContainer,
          image: hasImage
              ? DecorationImage(
                  image: FileImage(File(imagePath!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!hasImage)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFAEC4FF), AppColors.surfaceContainer],
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.30),
                  ],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_camera_rounded, color: AppColors.link),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    hasImage ? 'CHANGE COVER IMAGE' : 'ADD COVER IMAGE',
                    style: context.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      color: AppColors.link,
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

class _ColorOption {
  const _ColorOption(this.value, this.color);

  final String value;
  final Color color;
}

class _IconOption {
  const _IconOption(this.key, this.icon);

  final String key;
  final IconData icon;
}

const List<_ColorOption> _colorOptions = [
  _ColorOption('#1DB954', Color(0xFF1DB954)),
  _ColorOption('#2F6BFF', Color(0xFF2F6BFF)),
  _ColorOption('#F4B400', Color(0xFFF4B400)),
  _ColorOption('#E91E63', Color(0xFFE91E63)),
  _ColorOption('#9C27B0', Color(0xFF9C27B0)),
  _ColorOption('#FF8F00', Color(0xFFFF8F00)),
];

const List<_IconOption> _iconOptions = [
  _IconOption('book', Icons.menu_book_rounded),
  _IconOption('layers', Icons.layers_rounded),
  _IconOption('globe', Icons.public_rounded),
  _IconOption('food', Icons.restaurant_rounded),
  _IconOption('language', Icons.record_voice_over_rounded),
  _IconOption('edit', Icons.edit_rounded),
  _IconOption('music', Icons.graphic_eq_rounded),
  _IconOption('fitness', Icons.fitness_center_rounded),
  _IconOption('camera', Icons.photo_camera_rounded),
  _IconOption('science', Icons.science_rounded),
  _IconOption('brain', Icons.psychology_rounded),
  _IconOption('compass', Icons.explore_rounded),
];
