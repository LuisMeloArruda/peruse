import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:peruse/core/theme/theme.dart';

/// optional prefix; password fields get a visibility toggle unless [suffixIcon] is set.
class PeruseTextField extends StatefulWidget {
  const PeruseTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.obscureText = false,
    this.showVisibilityToggle,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.autofillHints,
    this.enabled = true,
    this.maxLines = 1,
    this.inputFormatters,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  final String? labelText;

  final String? hintText;
  final bool obscureText;

  final bool? showVisibilityToggle;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<PeruseTextField> createState() => _PeruseTextFieldState();
}

class _PeruseTextFieldState extends State<PeruseTextField> {
  late bool _obscureText = widget.obscureText;

  @override
  void didUpdateWidget(PeruseTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText) {
      _obscureText = widget.obscureText;
    }
  }

  bool get _showToggle {
    if (widget.suffixIcon != null) return false;
    final auto = widget.showVisibilityToggle ?? widget.obscureText;
    return auto && widget.obscureText;
  }

  OutlineInputBorder _border(Color? color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: color == null
          ? BorderSide.none
          : BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = context.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: AppColors.onSurfaceVariant,
      height: 24 / 16,
    );

    final hasPrefix = widget.prefixIcon != null;
    final decoration = InputDecoration(
      hintText: widget.hintText,
      prefixIcon: widget.prefixIcon,
      prefixIconConstraints: hasPrefix
          ? const BoxConstraints(minWidth: 48, minHeight: 40)
          : null,
      suffixIcon: widget.suffixIcon ?? _buildVisibilitySuffix(context),
      filled: true,
      fillColor: AppColors.surfaceMuted,
      border: _border(null),
      enabledBorder: _border(null),
      disabledBorder: _border(null),
      focusedBorder: _border(AppColors.primary, width: 2),
      errorBorder: _border(AppColors.error),
      focusedErrorBorder: _border(AppColors.error, width: 2),
      contentPadding: EdgeInsets.fromLTRB(
        hasPrefix ? 0 : AppSpacing.md,
        18,
        AppSpacing.md,
        18,
      ),
      hintStyle: context.textTheme.bodyLarge?.copyWith(color: AppColors.hint),
    );

    final field = TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints: widget.autofillHints,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      inputFormatters: widget.inputFormatters,
      style: context.textTheme.bodyLarge?.copyWith(color: AppColors.onSurface),
      cursorColor: AppColors.primary,
      decoration: decoration,
    );

    if (widget.labelText == null || widget.labelText!.isEmpty) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.labelText!.toUpperCase(), style: labelStyle),
        const SizedBox(height: AppSpacing.xs),
        field,
      ],
    );
  }

  Widget? _buildVisibilitySuffix(BuildContext context) {
    if (!_showToggle) return null;
    return IconButton(
      onPressed: () => setState(() => _obscureText = !_obscureText),
      icon: Icon(
        _obscureText
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        size: 22,
      ),
      color: AppColors.onSurfaceVariant,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.all(8),
      ),
      tooltip: _obscureText ? 'Show password' : 'Hide password',
    );
  }
}
