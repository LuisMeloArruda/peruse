import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:peruse/features/auth/domain/entities/app_user.dart';
import 'package:peruse/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final SupabaseClient _client;
  static const _webClientId =
      '677255136728-okohb2rap1lsamm92p0ekppj874su624.apps.googleusercontent.com';
  final GoogleSignIn _googleSignIn;

  AuthRepositoryImpl(this._client)
      : _googleSignIn = GoogleSignIn(serverClientId: _webClientId);

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
  Future<void> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Sign-In canceled.');
      }

      final googleAuth = await googleUser.authentication;

      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null || accessToken == null) {
        throw Exception('Failure: idToken and accessToken Google.');
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (error) {
      throw Exception('Google Sign-In failed: $error');
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      await _googleSignIn.signOut();
    }
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