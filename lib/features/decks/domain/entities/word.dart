class AppWord {
  final String id;
  final String text;
  final String? imageUrl;
  final double confidence;
  final String? sourceScanId;
  final int createdAt;

  const AppWord({
    required this.id,
    required this.text,
    this.imageUrl,
    required this.confidence,
    this.sourceScanId,
    required this.createdAt,
  });
}
