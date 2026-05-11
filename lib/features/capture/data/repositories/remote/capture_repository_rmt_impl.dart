import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:peruse/features/capture/domain/entities/capture.dart';
import 'package:peruse/features/capture/domain/entities/label.dart';
import 'package:peruse/features/capture/domain/repositories/capture_repository.dart';
import '../../models/capture_model.dart';

class CaptureRepositoryImpl implements ICaptureRepository {
  final SupabaseClient client;

  CaptureRepositoryImpl(this.client);

  @override
  Future<String> uploadImageToStorage(String localPath, String path) async {
    final file = File(localPath);
    final bucket = client.storage.from('captures');

    try {
      await bucket.upload(path, file, fileOptions: const FileOptions(upsert: true));
      return path;
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  @override
  Future<void> createRemoteCapture(Capture capture) async {
    final capMap = {
      'user_id': client.auth.currentUser?.id,
      'storage_path': capture.remoteId ?? '',
      'public_url': null,
    };

    final inserted = await client.from('captures').insert(capMap).select().maybeSingle();

    if (inserted == null) throw Exception('Failed to insert capture');

    final captureId = (inserted['id'] as String?) ?? '';

    // insert labels
    for (final lbl in capture.labels) {
      await client.from('object_labels').insert({
        'capture_id': captureId,
        'label': lbl.text,
        'confidence': lbl.confidence,
        'bbox': lbl.bbox,
        'language': lbl.language,
      });
    }
  }

  // Local methods left unimplemented in remote impl; adapt as needed
  @override
  Future<Capture> saveLocalCapture(String localPath, List<Label> labels) {
    throw UnimplementedError();
  }

  @override
  Future<List<Capture>> getLocalCaptures() {
    throw UnimplementedError();
  }

  @override
  Future<void> syncPendingCaptures() async {
    throw UnimplementedError();
  }
}
