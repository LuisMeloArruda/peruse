import 'package:meta/meta.dart';

@immutable
class AppUserProfile {
  final String userId;
  final String preferredLanguage;
  final int createdAt;
  final int updatedAt;

  const AppUserProfile({
    required this.userId,
    required this.preferredLanguage,
    required this.createdAt,
    required this.updatedAt,
  });

  AppUserProfile copyWith({
    String? userId,
    String? preferredLanguage,
    int? createdAt,
    int? updatedAt,
  }) {
    return AppUserProfile(
      userId: userId ?? this.userId,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}