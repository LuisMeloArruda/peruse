import 'package:flutter/material.dart';
import 'package:peruse/core/theme/theme.dart';

class AddDeckScreen extends StatelessWidget {
  const AddDeckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Deck')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'Add Deck screen placeholder',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
