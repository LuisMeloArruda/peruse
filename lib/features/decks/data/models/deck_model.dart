import 'package:drift/drift.dart';
import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/features/decks/domain/entities/deck.dart';

class DeckModel {
  final String id;
  final String name;
  final String userId;
  final String color;
  final String icon;
  final int createdAt;
  final bool isSynced;

  const DeckModel({
    required this.id,
    required this.name,
    required this.userId,
    required this.color,
    required this.icon,
    required this.createdAt,
    this.isSynced = true,
  });

  factory DeckModel.fromJson(Map<String, dynamic> json, {bool isSynced = true}) {
    final createdAtValue = json['created_at'];
    final createdAtMillis = createdAtValue is int
        ? createdAtValue
        : DateTime.parse(createdAtValue as String).millisecondsSinceEpoch;

    return DeckModel(
      id: json['id'] as String,
      name: json['name'] as String,
      userId: json['user_id'] as String,
      color: json['color'] as String,
      icon: json['icon'] as String,
      createdAt: createdAtMillis,
      isSynced: isSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'user_id': userId,
      'color': color,
      'icon': icon,
      'created_at':
          DateTime.fromMillisecondsSinceEpoch(createdAt).toIso8601String(),
    };
  }

  factory DeckModel.fromDrift(LocalDeck local) {
    return DeckModel(
      id: local.id,
      name: local.name,
      userId: local.userId,
      color: local.color,
      icon: local.icon,
      createdAt: local.createdAt.toInt(),
      isSynced: local.isSynced,
    );
  }

  LocalDeck toDriftData() {
    return LocalDeck(
      id: id,
      name: name,
      userId: userId,
      color: color,
      icon: icon,
      createdAt: BigInt.from(createdAt),
      isSynced: isSynced,
    );
  }

  DecksTableCompanion toCompanion({bool? isSyncedOverride}) {
    return DecksTableCompanion.insert(
      id: id,
      name: name,
      userId: userId,
      color: color,
      icon: icon,
      createdAt: BigInt.from(createdAt),
      isSynced: Value(isSyncedOverride ?? isSynced),
    );
  }

  AppDeck toEntity() {
    return AppDeck(
      id: id,
      name: name,
      userId: userId,
      color: color,
      icon: icon,
      createdAt: createdAt,
    );
  }

  factory DeckModel.fromEntity(AppDeck entity, {bool isSynced = true}) {
    return DeckModel(
      id: entity.id,
      name: entity.name,
      userId: entity.userId,
      color: entity.color,
      icon: entity.icon,
      createdAt: entity.createdAt,
      isSynced: isSynced,
    );
  }
}
