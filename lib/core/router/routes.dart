abstract final class AppRoutes {
  AppRoutes._();

  static const String home = '/decks';
  static const String decks = '/decks';
  static const String addDeck = '/decks/add';
  static const String capture = '/capture';
  static const String captureResult = '/capture-result';
  static const String study = '/study';
  static const String growth = '/growth';
  static const String profile = '/profile';
  static const String login = '/login';
  static const String register = '/register';

  static String deckDetail(String deckId) => '/decks/$deckId';
  static String wordDetail(String deckId, String wordId) =>
      '/decks/$deckId/words/$wordId';
  static String deckStudy(String deckId) => '/decks/$deckId/study';
  static String deckAddWord(String deckId) => '/decks/$deckId/add-word';
}
