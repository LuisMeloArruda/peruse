class DeckMasteryStats {
  const DeckMasteryStats({
    required this.accuracy,
    required this.totalAnswers,
    required this.correctAnswers,
  });

  final double accuracy;
  final int totalAnswers;
  final int correctAnswers;

  static const empty = DeckMasteryStats(
    accuracy: 0,
    totalAnswers: 0,
    correctAnswers: 0,
  );
}
