class AppFlashcard {
  final String id;
  final String deckId;
  final String wordId;
  final String? frontText;
  final String? backText;
  final String? mediaUrl;
  final String? mediaType;
  final int position;
  final bool isDeleted;
  final int revision;
  final String? modifiedBy;
  final int createdAt;
  final int updatedAt;
  final bool isSynced;

  const AppFlashcard({
    required this.id,
    required this.deckId,
    required this.wordId,
    this.frontText,
    this.backText,
    this.mediaUrl,
    this.mediaType,
    required this.position,
    required this.isDeleted,
    required this.revision,
    this.modifiedBy,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
  });

  AppFlashcard copyWith({
    String? id,
    String? deckId,
    String? wordId,
    String? frontText,
    String? backText,
    String? mediaUrl,
    String? mediaType,
    int? position,
    bool? isDeleted,
    int? revision,
    String? modifiedBy,
    int? createdAt,
    int? updatedAt,
    bool? isSynced,
  }) {
    return AppFlashcard(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      wordId: wordId ?? this.wordId,
      frontText: frontText ?? this.frontText,
      backText: backText ?? this.backText,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      position: position ?? this.position,
      isDeleted: isDeleted ?? this.isDeleted,
      revision: revision ?? this.revision,
      modifiedBy: modifiedBy ?? this.modifiedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}