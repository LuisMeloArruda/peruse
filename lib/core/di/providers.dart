import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:peruse/data/local/database/app_database.dart';
import 'package:peruse/features/auth/data/repositories/remote/auth_repository_rmt_impl.dart';
import 'package:peruse/features/auth/domain/repositories/auth_repository.dart';
import 'package:peruse/features/auth/domain/usecases/auth/login_use_case.dart';
import 'package:peruse/features/auth/domain/usecases/auth/register_use_case.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) {
  return Supabase.instance.client;
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
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