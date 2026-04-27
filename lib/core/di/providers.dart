import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth/login_use_case.dart';
import '../../domain/usecases/auth/register_use_case.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) {
  return Supabase.instance.client;
}

@Riverpod(keepAlive: true)
IAuthRepository authRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepositoryImpl(client);
}

@riverpod
LoginUseCase loginUseCase(Ref ref) {
  final repository = ref.watch(authRepositoryProvider);
  return LoginUseCase(repository);
}

@riverpod
RegisterUseCase registerUseCase(Ref ref) {
  final repository = ref.watch(authRepositoryProvider);
  return RegisterUseCase(repository);
}