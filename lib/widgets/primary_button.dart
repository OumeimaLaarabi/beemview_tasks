import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Full-width gradient call-to-action with a loading state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Shows a spinner instead of [label] and ignores taps.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(13);
    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? '$label, in progress' : label,
      child: Opacity(
        opacity: loading ? 0.8 : (enabled ? 1 : 0.5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: AppColors.buttonGradient,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4D45C8).withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: enabled ? onPressed : null,
              child: SizedBox(
                height: 50,
                child: Center(
                  child: loading
                      ? const SizedBox.square(
                          dimension: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                            backgroundColor: Color(0x4DFFFFFF),
                          ),
                        )
                      : ExcludeSemantics(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
