import 'package:drift/drift.dart';

import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/features/flashcards/domain/entities/flashcard.dart';

class FlashcardModel {
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

  const FlashcardModel({
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

  factory FlashcardModel.fromJson(
    Map<String, dynamic> json, {
    bool isSynced = true,
  }) {
    return FlashcardModel(
      id: json['id'] as String,
      deckId: json['deck_id'] as String,
      wordId: json['word_id'] as String,
      frontText: json['front_text'] as String?,
      backText: json['back_text'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      position: _parseInt(json['position']),
      isDeleted: _parseBool(json['is_deleted']),
      revision: _parseInt(json['revision']),
      modifiedBy: json['modified_by'] as String?,
      createdAt: _parseRemoteMillis(json['created_at']),
      updatedAt: _parseRemoteMillis(json['updated_at']),
      isSynced: isSynced,
    );
  }

  factory FlashcardModel.fromDrift(LocalFlashcard local) {
    return FlashcardModel(
      id: local.id,
      deckId: local.deckId,
      wordId: local.wordId,
      frontText: local.frontText,
      backText: local.backText,
      mediaUrl: local.mediaUrl,
      mediaType: local.mediaType,
      position: local.position,
      isDeleted: local.isDeleted,
      revision: local.revision.toInt(),
      modifiedBy: local.modifiedBy,
      createdAt: local.createdAt.toInt(),
      updatedAt: local.updatedAt.toInt(),
      isSynced: local.synced,
    );
  }

  AppFlashcard toEntity() {
    return AppFlashcard(
      id: id,
      deckId: deckId,
      wordId: wordId,
      frontText: frontText,
      backText: backText,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      position: position,
      isDeleted: isDeleted,
      revision: revision,
      modifiedBy: modifiedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isSynced: isSynced,
    );
  }

  FlashcardsTableCompanion toCompanion({bool? isSyncedOverride}) {
    return FlashcardsTableCompanion.insert(
      id: id,
      deckId: deckId,
      wordId: wordId,
      frontText: Value(frontText),
      backText: Value(backText),
      mediaUrl: Value(mediaUrl),
      mediaType: Value(mediaType),
      position: Value(position),
      isDeleted: Value(isDeleted),
      revision: Value(BigInt.from(revision)),
      modifiedBy: Value(modifiedBy),
      createdAt: BigInt.from(createdAt),
      updatedAt: BigInt.from(updatedAt),
      synced: Value(isSyncedOverride ?? isSynced),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deck_id': deckId,
      'word_id': wordId,
      'front_text': frontText,
      'back_text': backText,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'position': position,
      'is_deleted': isDeleted,
      'revision': revision,
      'modified_by': modifiedBy,
      'created_at': DateTime.fromMillisecondsSinceEpoch(
        createdAt,
      ).toIso8601String(),
      'updated_at': DateTime.fromMillisecondsSinceEpoch(
        updatedAt,
      ).toIso8601String(),
    };
  }

  factory FlashcardModel.fromEntity(
    AppFlashcard entity, {
    bool isSynced = true,
  }) {
    return FlashcardModel(
      id: entity.id,
      deckId: entity.deckId,
      wordId: entity.wordId,
      frontText: entity.frontText,
      backText: entity.backText,
      mediaUrl: entity.mediaUrl,
      mediaType: entity.mediaType,
      position: entity.position,
      isDeleted: entity.isDeleted,
      revision: entity.revision,
      modifiedBy: entity.modifiedBy,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isSynced: isSynced,
    );
  }

  static int _parseRemoteMillis(dynamic value) {
    if (value is int) return value;
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value).millisecondsSinceEpoch;
      } catch (_) {
        return 0;
      }
    }
    return 0;
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }
}
