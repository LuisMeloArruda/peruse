class LlmRequest {
  /// map of word and its confidence score
  final Map<String, double> input;
  final String sourceLanguage;
  final String targetLanguage;

  const LlmRequest({
    required this.input,
    required this.sourceLanguage,
    required this.targetLanguage,
  });
}
