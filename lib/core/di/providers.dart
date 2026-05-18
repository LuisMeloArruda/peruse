import 'package:camera/camera.dart' as camera;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:peruse/features/auth/data/repositories/remote/auth_repository_rmt_impl.dart';
import 'package:peruse/features/auth/domain/repositories/auth_repository.dart';
import 'package:peruse/features/auth/domain/usecases/auth/login_use_case.dart';
import 'package:peruse/features/auth/domain/usecases/auth/register_use_case.dart';
import 'package:peruse/features/capture/data/local/app_database.dart';
import 'package:peruse/features/capture/data/repositories/local/local_capture_repository.dart';
import 'package:peruse/features/capture/domain/repositories/capture_repository.dart';

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

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  return AppDatabase();
}

@riverpod
Future<List<camera.CameraDescription>> availableCameras(Ref ref) async {
  try {
    return await camera.availableCameras();
  } catch (_) {
    return const [];
  }
}

@Riverpod(keepAlive: true)
ICaptureRepository captureRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  final database = ref.watch(appDatabaseProvider);
  return LocalCaptureRepository(database, client);
}