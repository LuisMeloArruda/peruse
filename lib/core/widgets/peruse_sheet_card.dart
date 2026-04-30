import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// White rounded surface with the soft shadow used on chart / stat cards in Figma.
class PeruseSheetCard extends StatelessWidget {
  const PeruseSheetCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadius.sheet,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? const [
                BoxShadow(
                  color: Color(0x0A2C2F2F),
                  blurRadius: 40,
                  offset: Offset(0, 20),
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}
