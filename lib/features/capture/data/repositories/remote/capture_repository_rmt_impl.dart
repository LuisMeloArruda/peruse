import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:peruse/features/capture/domain/entities/capture.dart';
import 'package:peruse/features/capture/domain/entities/label.dart';
import 'package:peruse/features/capture/domain/repositories/capture_repository.dart';

class CaptureRepositoryImpl implements ICaptureRepository {
  final SupabaseClient client;

  CaptureRepositoryImpl(this.client);

  @override
  Future<String> uploadImageToStorage(String localPath, String path) async {
    final file = File(localPath);
    final bucket = client.storage.from('captures');

    try {
      await bucket.upload(
        path,
        file,
        fileOptions: const FileOptions(upsert: true),
      );
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

    final inserted = await client
        .from('captures')
        .insert(capMap)
        .select()
        .maybeSingle();

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

  @override
  Future<Capture> saveLocalCapture(String localPath, List<Label> labels) async {
    // This method should not be called on the remote impl.
    // Local captures are handled by LocalCaptureRepository.
    throw UnsupportedError(
      'saveLocalCapture is not supported in remote repository. '
      'Use LocalCaptureRepository instead.',
    );
  }

  @override
  Future<List<Capture>> getLocalCaptures() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch captures from remote database
      final response = await client
          .from('captures')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final captures = <Capture>[];

      for (final row in response as List) {
        final captureId = row['id'] as String;

        // Fetch labels for this capture
        final labelsResponse = await client
            .from('object_labels')
            .select()
            .eq('capture_id', captureId);

        final labels = (labelsResponse as List)
            .map(
              (labelRow) => Label(
                text: labelRow['label'] as String,
                confidence: (labelRow['confidence'] as num).toDouble(),
                language: labelRow['language'] as String? ?? 'en',
                bbox: labelRow['bbox'] != null
                    ? Map<String, double>.from(labelRow['bbox'] as Map)
                    : null,
              ),
            )
            .toList();

        captures.add(
          Capture(
            id: captureId,
            remoteId: captureId,
            localPath: row['storage_path'] as String? ?? '',
            createdAt: DateTime.parse(row['created_at'] as String),
            labels: labels,
            status: row['uploaded'] == true ? 'uploaded' : 'pending',
          ),
        );
      }

      return captures;
    } catch (e) {
      throw Exception('Failed to fetch remote captures: $e');
    }
  }

  @override
  Future<void> syncPendingCaptures() async {
    // Sync operations should be handled by LocalCaptureRepository which manages
    // the local database state. This method is not applicable for the remote impl.
    throw UnsupportedError(
      'syncPendingCaptures is not supported in remote repository. '
      'Use LocalCaptureRepository instead.',
    );
  }
}
