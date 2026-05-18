import 'label.dart';

class Capture {
  final String id;
  final String localPath;
  final DateTime createdAt;
  final String? remoteId;
  final List<Label> labels;
  final String status; // pending, uploading, uploaded, failed

  Capture({
    required this.id,
    required this.localPath,
    required this.createdAt,
    this.remoteId,
    this.labels = const [],
    this.status = 'pending',
  });
}
