import 'package:drift/drift.dart';
import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/features/decks/domain/entities/deck.dart';

class DeckModel {
  final String id;
  final String name;
  final String? bio;
  final String userId;
  final String color;
  final String icon;
  final String? coverImageUrl;
  final int createdAt;
  final bool isDeleted;
  final bool isSynced;

  const DeckModel({
    required this.id,
    required this.name,
    this.bio,
    required this.userId,
    required this.color,
    required this.icon,
    this.coverImageUrl,
    required this.createdAt,
    this.isDeleted = false,
    this.isSynced = true,
  });

  factory DeckModel.fromJson(
    Map<String, dynamic> json, {
    bool isSynced = true,
  }) {
    final createdAtValue = json['created_at'];
    final createdAtMillis = createdAtValue is int
        ? createdAtValue
        : DateTime.parse(createdAtValue as String).millisecondsSinceEpoch;

    return DeckModel(
      id: json['id'] as String,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      userId: json['user_id'] as String,
      color: json['color'] as String,
      icon: json['icon'] as String,
      coverImageUrl: json['cover_image_url'] as String?,
      createdAt: createdAtMillis,
      isDeleted: json['is_deleted'] == true,
      isSynced: isSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bio': bio,
      'user_id': userId,
      'color': color,
      'icon': icon,
      'cover_image_url': coverImageUrl,
      'created_at': DateTime.fromMillisecondsSinceEpoch(
        createdAt,
      ).toIso8601String(),
    };
  }

  factory DeckModel.fromDrift(LocalDeck local) {
    return DeckModel(
      id: local.id,
      name: local.name,
      bio: local.bio,
      userId: local.userId,
      color: local.color,
      icon: local.icon,
      coverImageUrl: local.coverImageUrl,
      createdAt: local.createdAt.toInt(),
      isDeleted: local.isDeleted,
      isSynced: local.isSynced,
    );
  }

  LocalDeck toDriftData() {
    return LocalDeck(
      id: id,
      name: name,
      bio: bio,
      userId: userId,
      color: color,
      icon: icon,
      coverImageUrl: coverImageUrl,
      createdAt: BigInt.from(createdAt),
      isDeleted: isDeleted,
      isSynced: isSynced,
    );
  }

  DecksTableCompanion toCompanion({bool? isSyncedOverride}) {
    return DecksTableCompanion.insert(
      id: id,
      name: name,
      bio: Value(bio),
      userId: userId,
      color: color,
      icon: icon,
      coverImageUrl: Value(coverImageUrl),
      createdAt: BigInt.from(createdAt),
      isSynced: Value(isSyncedOverride ?? isSynced),
    );
  }

  AppDeck toEntity() {
    return AppDeck(
      id: id,
      name: name,
      bio: bio,
      userId: userId,
      color: color,
      icon: icon,
      coverImageUrl: coverImageUrl,
      createdAt: createdAt,
    );
  }

  factory DeckModel.fromEntity(AppDeck entity, {bool isSynced = true}) {
    return DeckModel(
      id: entity.id,
      name: entity.name,
      bio: entity.bio,
      userId: entity.userId,
      color: entity.color,
      icon: entity.icon,
      coverImageUrl: entity.coverImageUrl,
      createdAt: entity.createdAt,
      isDeleted: false,
      isSynced: isSynced,
    );
  }
}
