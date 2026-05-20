import '../../domain/entities/capture.dart';
import 'label_model.dart';

class CaptureModel extends Capture {
  CaptureModel({
    required super.id,
    required super.localPath,
    required super.createdAt,
    super.remoteId,
    super.labels = const [],
    super.status = 'pending',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'localPath': localPath,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'remoteId': remoteId,
    'labels': labels.map((l) => (l as LabelModel).toMap()).toList(),
    'status': status,
  };

  factory CaptureModel.fromMap(Map<String, dynamic> map) => CaptureModel(
    id: map['id'] as String,
    localPath: map['localPath'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    remoteId: map['remoteId'] as String?,
    labels: map['labels'] == null
        ? []
        : List<LabelModel>.from(
            (map['labels'] as List).map(
              (m) => LabelModel.fromMap(Map<String, dynamic>.from(m)),
            ),
          ),
    status: map['status'] as String? ?? 'pending',
  );
}
