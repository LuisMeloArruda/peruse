import '../../entities/app_user.dart';
import '../../repositories/auth_repository.dart';

class RegisterUseCase {
  final IAuthRepository _repository;

  RegisterUseCase(this._repository);

  Future<AppUser> call(String email, String password) async {
    return await _repository.signUpWithEmail(email, password);
  }
}