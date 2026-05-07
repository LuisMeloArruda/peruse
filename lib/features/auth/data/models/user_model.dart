import 'package:peruse/features/auth/domain/entities/app_user.dart';

class UserModel {
  final String id;
  final String email;
  final String? name;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': String id,
        'email': String email,
      } =>
        UserModel(
          id: id,
          email: email,
          name: json['raw_user_meta_data']?['display_name'] as String?,
        ),
      _ => throw const FormatException('Error processing UserModel: invalid JSON'),
    };
  }

  AppUser toEntity() {
    return AppUser(
      id: id,
      email: email,
      name: name,
    );
  }
}