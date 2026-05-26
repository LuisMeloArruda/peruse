import 'package:peruse/features/auth/domain/entities/app_user.dart';

abstract interface class IAuthRepository {
  Future<AppUser> signInWithEmail(String email, String password);

  Future<AppUser> signUpWithEmail(String email, String password);

  Future<void> signInWithGoogle();

  Future<void> signOut();

  Future<void> deleteAccount();

  Stream<AppUser?> get authStateChanges;

  AppUser? get currentUser;
}
