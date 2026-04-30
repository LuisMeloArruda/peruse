import 'package:flutter/material.dart';

extension TypographyContext on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
}
