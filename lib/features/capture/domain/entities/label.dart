class Label {
  final String text;
  final double confidence;
  final Map<String, double>? bbox;
  final String language;

  const Label({
    required this.text,
    required this.confidence,
    this.bbox,
    this.language = 'en',
  });
}
