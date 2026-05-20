import 'package:flutter/material.dart';

import 'package:peruse/features/flashcards/presentation/flashcard_study_screen.dart';

class StudySessionScreen extends StatelessWidget {
  const StudySessionScreen({super.key, required this.deckId});

  final String deckId;

  @override
  Widget build(BuildContext context) {
    return FlashcardStudyScreen(deckId: deckId);
  }
}
