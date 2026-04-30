import '../../entities/app_user.dart';
import '../../repositories/auth_repository.dart';

class LoginUseCase {
  final IAuthRepository _repository;

  LoginUseCase(this._repository);

  Future<AppUser> call(String email, String password) async {
    return await _repository.signInWithEmail(email, password);
  }
}