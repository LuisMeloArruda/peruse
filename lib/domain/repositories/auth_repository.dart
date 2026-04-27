import '../entities/app_user.dart';

abstract interface class IAuthRepository {
  Future<AppUser> signInWithEmail(String email, String password);
  
  Future<AppUser> signUpWithEmail(String email, String password);
  
  Future<void> signOut();
  
  Stream<AppUser?> get authStateChanges;
  
  AppUser? get currentUser;
}