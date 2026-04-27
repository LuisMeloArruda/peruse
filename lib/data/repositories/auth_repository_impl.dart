import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final SupabaseClient _client;

  AuthRepositoryImpl(this._client);

  @override
  Future<AppUser> signInWithEmail(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    return response.user!.toEntity();
  }

  @override
  Future<AppUser> signUpWithEmail(String email, String password) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    return response.user!.toEntity();
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Stream<AppUser?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((data) {
        final user = data.session?.user; 
        return user?.toEntity();
      });

  @override
  AppUser? get currentUser => _client.auth.currentUser?.toEntity();
}

extension on User {
  AppUser toEntity() {
    return AppUser(
      id: id,
      email: email ?? '',
      name: userMetadata?['display_name'] as String?,
    );
  }
}