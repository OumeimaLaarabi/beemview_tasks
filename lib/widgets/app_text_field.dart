import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'line_icon.dart';

/// Labelled form field from the design: label above a 52px rounded box with
/// a leading icon. Focus adds a brand border and a soft outer ring; the
/// validation message sits below the box, outside the ring.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.autocorrect = true,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
  });

  final String label;
  final LineIcons icon;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool autocorrect;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Optional action at the end of the box, e.g. a show-password toggle.
  final Widget? trailing;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      // Validate the controller, so autofilled text is always included.
      validator: (_) => widget.validator?.call(widget.controller.text),
      builder: (field) {
        final focused = _focus.hasFocus;
        final error = field.errorText;
        final accent = error != null
            ? AppColors.danger
            : (focused ? AppColors.brand : AppColors.fieldIcon);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 7),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              padding: const EdgeInsets.only(left: 14, right: 6),
              decoration: BoxDecoration(
                color: focused ? AppColors.surface : AppColors.fieldFill,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: error != null
                      ? AppColors.danger
                      : (focused ? AppColors.brand : AppColors.fieldBorder),
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: error != null
                              ? AppColors.dangerSoft
                              : AppColors.brandSoft,
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  LineIcon(widget.icon, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      label: widget.label,
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        enabled: widget.enabled,
                        keyboardType: widget.keyboardType,
                        textInputAction: widget.textInputAction,
                        autofillHints: widget.autofillHints,
                        obscureText: widget.obscureText,
                        autocorrect: widget.autocorrect,
                        enableSuggestions: !widget.obscureText,
                        onSubmitted: widget.onSubmitted,
                        onChanged: (value) {
                          field.didChange(value);
                          widget.onChanged?.call(value);
                        },
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration.collapsed(
                          hintText: null,
                        ),
                      ),
                    ),
                  ),
                  if (widget.trailing != null)
                    widget.trailing!
                  else
                    const SizedBox(width: 8),
                ],
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
