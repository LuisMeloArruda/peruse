class UserGlobalStats {
  const UserGlobalStats({
    required this.totalWords,
    required this.lifetimeAccuracy,
    required this.wordsStudiedToday,
    required this.currentStreak,
  });

  final int totalWords;
  final double lifetimeAccuracy;
  final int wordsStudiedToday;
  final int currentStreak;

  static const empty = UserGlobalStats(
    totalWords: 0,
    lifetimeAccuracy: 0,
    wordsStudiedToday: 0,
    currentStreak: 0,
  );
}
