import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FreeDictionaryApi {
  FreeDictionaryApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<DictionaryEntry?> fetchEntry(String word) async {
    final uri = Uri.parse(
      'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word)}',
    );

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        debugPrint('Dictionary API error: ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        return null;
      }

      final first = decoded.first as Map<String, dynamic>;
      final phonetic = _extractPhonetic(first);
      final audioUrl = _extractAudioUrl(first);
      final meaning = _extractMeaning(first);

      return DictionaryEntry(
        definition: meaning.definition,
        example: meaning.example,
        partOfSpeech: meaning.partOfSpeech,
        phonetic: phonetic,
        audioUrl: audioUrl,
        rawJson: jsonEncode(first),
      );
    } catch (e) {
      debugPrint('Dictionary API exception: $e');
      return null;
    }
  }

  String _extractPhonetic(Map<String, dynamic> entry) {
    final phonetic = entry['phonetic'];
    if (phonetic is String && phonetic.isNotEmpty) {
      return phonetic;
    }

    final phonetics = entry['phonetics'];
    if (phonetics is List) {
      for (final item in phonetics) {
        if (item is Map<String, dynamic>) {
          final text = item['text'];
          if (text is String && text.isNotEmpty) {
            return text;
          }
        }
      }
    }

    return '';
  }

  String _extractAudioUrl(Map<String, dynamic> entry) {
    final phonetics = entry['phonetics'];
    if (phonetics is List) {
      for (final item in phonetics) {
        if (item is Map<String, dynamic>) {
          final audio = item['audio'];
          if (audio is String && audio.isNotEmpty) {
            return audio;
          }
        }
      }
    }

    return '';
  }

  _Meaning _extractMeaning(Map<String, dynamic> entry) {
    final meanings = entry['meanings'];
    if (meanings is List) {
      for (final meaning in meanings) {
        if (meaning is Map<String, dynamic>) {
          final partOfSpeech = meaning['partOfSpeech'];
          final definitions = meaning['definitions'];
          if (definitions is List && definitions.isNotEmpty) {
            final firstDefinition = definitions.first;
            if (firstDefinition is Map<String, dynamic>) {
              final definition = firstDefinition['definition'];
              final example = firstDefinition['example'];
              return _Meaning(
                definition: definition is String ? definition : '',
                example: example is String ? example : '',
                partOfSpeech: partOfSpeech is String ? partOfSpeech : '',
              );
            }
          }
        }
      }
    }

    return const _Meaning(definition: '', example: '', partOfSpeech: '');
  }
}

class DictionaryEntry {
  const DictionaryEntry({
    required this.definition,
    required this.example,
    required this.partOfSpeech,
    required this.phonetic,
    required this.audioUrl,
    required this.rawJson,
  });

  final String definition;
  final String example;
  final String partOfSpeech;
  final String phonetic;
  final String audioUrl;
  final String rawJson;
}

class _Meaning {
  const _Meaning({
    required this.definition,
    required this.example,
    required this.partOfSpeech,
  });

  final String definition;
  final String example;
  final String partOfSpeech;
}
