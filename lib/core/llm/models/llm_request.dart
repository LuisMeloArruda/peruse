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

  String get _normalizedInputKey {
    final entries = input.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((e) => '${e.key}=${e.value}').join('|');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LlmRequest &&
        other.sourceLanguage == sourceLanguage &&
        other.targetLanguage == targetLanguage &&
        other._normalizedInputKey == _normalizedInputKey;
  }

  @override
  int get hashCode =>
      Object.hash(sourceLanguage, targetLanguage, _normalizedInputKey);
}
