import 'package:flutter/material.dart';
import 'package:flutter_localization_agent/services/translation_service.dart';
import 'package:flutter_localization_agent/translation_localizations.dart';

extension LocaleExt on BuildContext {
  TranslationLocalizations get _translation =>
      TranslationLocalizations.of(this);
  TranslationService get translationService => _translation.service;
  String translate(String key, {Map<String, String>? args}) {
    var text = _translation.translate(key);
    if (args != null) {
      for (final entry in args.entries) {
        text = text.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return text;
  }
}
