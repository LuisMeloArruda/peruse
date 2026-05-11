import '../../domain/entities/label.dart';

class LabelModel extends Label {
  const LabelModel({
    required super.text,
    required super.confidence,
    super.bbox,
    super.language,
  });

  Map<String, dynamic> toMap() => {
        'text': text,
        'confidence': confidence,
        'bbox': bbox,
        'language': language,
      };

  factory LabelModel.fromMap(Map<String, dynamic> map) => LabelModel(
        text: map['text'] as String,
        confidence: (map['confidence'] as num).toDouble(),
        bbox: map['bbox'] == null
            ? null
            : Map<String, double>.from((map['bbox'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()))),
        language: map['language'] as String? ?? 'en',
      );
}
