class AppWordDetails {
  final String wordId;
  final String definition;
  final String example;
  final String partOfSpeech;
  final String phonetic;
  final String audioUrl;
  final String? rawJson;

  const AppWordDetails({
    required this.wordId,
    required this.definition,
    required this.example,
    required this.partOfSpeech,
    required this.phonetic,
    required this.audioUrl,
    this.rawJson,
  });
}
