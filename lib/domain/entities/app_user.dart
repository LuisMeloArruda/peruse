import 'package:meta/meta.dart';

typedef UserId = String;

@immutable
class AppUser {
  final UserId id;
  final String email;
  final String? name;

  const AppUser({
    required this.id,
    required this.email,
    this.name,
  });

  AppUser copyWith({
    UserId? id,
    String? email,
    String? name,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
    );
  }

  String get displayName => name ?? email.split('@').first;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ email.hashCode ^ name.hashCode;
}