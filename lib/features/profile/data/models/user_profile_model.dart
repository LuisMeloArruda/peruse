import 'package:drift/drift.dart';

import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/features/profile/domain/entities/user_profile.dart';

class UserProfileModel {
  final String userId;
  final String preferredLanguage;
  final int createdAt;
  final int updatedAt;
  final bool isSynced;

  const UserProfileModel({
    required this.userId,
    required this.preferredLanguage,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = true,
  });

  factory UserProfileModel.fromJson(
    Map<String, dynamic> json, {
    bool isSynced = true,
  }) {
    return UserProfileModel(
      userId: json['user_id'] as String,
      preferredLanguage: json['preferred_language'] as String? ?? 'en',
      createdAt: _parseDateValue(json['created_at']),
      updatedAt: _parseDateValue(json['updated_at']),
      isSynced: isSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'preferred_language': preferredLanguage,
      'created_at': DateTime.fromMillisecondsSinceEpoch(
        createdAt,
      ).toIso8601String(),
      'updated_at': DateTime.fromMillisecondsSinceEpoch(
        updatedAt,
      ).toIso8601String(),
    };
  }

  factory UserProfileModel.fromDrift(LocalProfile local) {
    return UserProfileModel(
      userId: local.userId,
      preferredLanguage: local.preferredLanguage,
      createdAt: local.createdAt.toInt(),
      updatedAt: local.updatedAt.toInt(),
      isSynced: local.isSynced,
    );
  }

  LocalProfile toDriftData() {
    return LocalProfile(
      userId: userId,
      preferredLanguage: preferredLanguage,
      createdAt: BigInt.from(createdAt),
      updatedAt: BigInt.from(updatedAt),
      isSynced: isSynced,
    );
  }

  ProfilesTableCompanion toCompanion({bool? isSyncedOverride}) {
    return ProfilesTableCompanion.insert(
      userId: userId,
      preferredLanguage: Value(preferredLanguage),
      createdAt: Value(BigInt.from(createdAt)),
      updatedAt: Value(BigInt.from(updatedAt)),
      isSynced: Value(isSyncedOverride ?? isSynced),
    );
  }

  AppUserProfile toEntity() {
    return AppUserProfile(
      userId: userId,
      preferredLanguage: preferredLanguage,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory UserProfileModel.fromEntity(
    AppUserProfile entity, {
    bool isSynced = true,
  }) {
    return UserProfileModel(
      userId: entity.userId,
      preferredLanguage: entity.preferredLanguage,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isSynced: isSynced,
    );
  }

  static int _parseDateValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).millisecondsSinceEpoch;
    }
    return 0;
  }
}
