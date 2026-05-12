import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:peruse/features/capture/data/local/app_database.dart';
import 'package:peruse/features/capture/domain/entities/capture.dart';
import 'package:peruse/features/capture/domain/entities/label.dart';
import 'package:peruse/features/capture/domain/repositories/capture_repository.dart';

enum CaptureSyncStatus { pending, uploading, uploaded, failed }

extension CaptureSyncStatusX on CaptureSyncStatus {
  int get value => index;

  static CaptureSyncStatus fromValue(int value) {
    if (value < 0 || value >= CaptureSyncStatus.values.length) {
      return CaptureSyncStatus.pending;
    }
    return CaptureSyncStatus.values[value];
  }
}

class LocalCaptureRepository implements ICaptureRepository {
  final AppDatabase database;
  final SupabaseClient client;
  final Uuid _uuid;

  LocalCaptureRepository(
    this.database,
    this.client, {
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  @override
  Future<Capture> saveLocalCapture(String localPath, List<Label> labels) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await database.into(database.localCaptures).insert(
          LocalCapturesCompanion.insert(
            id: id,
            localPath: localPath,
            status: CaptureSyncStatus.pending.value,
            createdAt: now,
            updatedAt: now,
          ),
        );

    for (final label in labels) {
      await database.into(database.localCaptureLabels).insert(
            LocalCaptureLabelsCompanion.insert(
              captureId: id,
              label: label.text,
              confidence: label.confidence,
              language: Value(label.language),
              bboxJson: Value(label.bbox == null ? null : jsonEncode(label.bbox)),
            ),
          );
    }

    return Capture(
      id: id,
      localPath: localPath,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      labels: labels,
      status: 'pending',
    );
  }

  @override
  Future<List<Capture>> getLocalCaptures() async {
    final query = database.select(database.localCaptures)
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);

    final rows = await query.get();

    final result = <Capture>[];
    for (final row in rows) {
      final labelRows = await (database.select(database.localCaptureLabels)
            ..where((tbl) => tbl.captureId.equals(row.id)))
          .get();

      result.add(
        Capture(
          id: row.id,
          localPath: row.localPath,
          createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
          remoteId: row.remoteId,
          labels: labelRows
              .map(
                (labelRow) => Label(
                  text: labelRow.label,
                  confidence: labelRow.confidence,
                  language: labelRow.language,
                  bbox: labelRow.bboxJson == null
                      ? null
                      : Map<String, double>.from(
                          jsonDecode(labelRow.bboxJson!) as Map,
                        ),
                ),
              )
              .toList(),
          status: CaptureSyncStatusX.fromValue(row.status).name,
        ),
      );
    }

    return result;
  }

  @override
  Future<void> syncPendingCaptures() async {
    final pendingRows = await (database.select(database.localCaptures)
          ..where((tbl) =>
              tbl.status.equals(CaptureSyncStatus.pending.value) |
              tbl.status.equals(CaptureSyncStatus.failed.value)))
        .get();

    for (final row in pendingRows) {
      await _syncSingleCapture(row);
    }
  }

  Future<void> _syncSingleCapture(LocalCapture captureRow) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final labels = await (database.select(database.localCaptureLabels)
          ..where((tbl) => tbl.captureId.equals(captureRow.id)))
        .get();

    await (database.update(database.localCaptures)
          ..where((tbl) => tbl.id.equals(captureRow.id)))
        .write(
      LocalCapturesCompanion(
        status: Value(CaptureSyncStatus.uploading.value),
        updatedAt: Value(now),
        uploadAttempts: Value(captureRow.uploadAttempts + 1),
        errorMessage: const Value(null),
      ),
    );

    try {
      final localFile = File(captureRow.localPath);
      if (!await localFile.exists()) {
        throw Exception('Local image not found: ${captureRow.localPath}');
      }

      final currentUserId = client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated. Please sign in again.');
      }

      final extension = p.extension(captureRow.localPath);
      final storagePath = 'captures/$currentUserId/${captureRow.id}$extension';
      await client.storage.from('captures').upload(storagePath, localFile);

      final captureInsert = await client.from('captures').insert({
        'user_id': client.auth.currentUser?.id,
        'storage_path': storagePath,
        'public_url': null,
        'uploaded': true,
      }).select('id').single();

      final remoteCaptureId = captureInsert['id'] as String;

      for (final labelRow in labels) {
        await client.from('object_labels').insert({
          'capture_id': remoteCaptureId,
          'label': labelRow.label,
          'confidence': labelRow.confidence,
          'bbox': labelRow.bboxJson == null ? null : jsonDecode(labelRow.bboxJson!),
          'language': labelRow.language,
        });
      }

      await (database.update(database.localCaptures)
            ..where((tbl) => tbl.id.equals(captureRow.id)))
          .write(
        LocalCapturesCompanion(
          remoteId: Value(remoteCaptureId),
          status: Value(CaptureSyncStatus.uploaded.value),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          errorMessage: const Value(null),
        ),
      );
    } catch (error) {
      final errorMessage = _toSyncErrorMessage(error);

      await (database.update(database.localCaptures)
            ..where((tbl) => tbl.id.equals(captureRow.id)))
          .write(
        LocalCapturesCompanion(
          status: Value(CaptureSyncStatus.failed.value),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          errorMessage: Value(errorMessage),
        ),
      );

      throw Exception(errorMessage);
    }
  }

  String _toSyncErrorMessage(Object error) {
    if (error is StorageException && error.statusCode == '403') {
      return 'Supabase Storage denied upload (403). Check policies for bucket "captures" on storage.objects.';
    }

    final message = error.toString();
    if (message.contains('row-level security policy')) {
      return 'Supabase denied insert due to RLS policy. Check policies for tables captures and object_labels.';
    }

    return message;
  }

  @override
  Future<String> uploadImageToStorage(String localPath, String path) async {
    final file = File(localPath);
    await client.storage.from('captures').upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  @override
  Future<void> createRemoteCapture(Capture capture) async {
    final remoteCapture = await client.from('captures').insert({
      'user_id': client.auth.currentUser?.id,
      'storage_path': capture.remoteId,
      'public_url': null,
      'uploaded': true,
    }).select('id').single();

    final remoteCaptureId = remoteCapture['id'] as String;

    for (final label in capture.labels) {
      await client.from('object_labels').insert({
        'capture_id': remoteCaptureId,
        'label': label.text,
        'confidence': label.confidence,
        'bbox': label.bbox,
        'language': label.language,
      });
    }
  }
}
