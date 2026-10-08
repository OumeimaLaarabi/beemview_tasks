import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Round avatar with up to two initials, tinted by a colour picked from the
/// name so the same person always gets the same colour.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 28,
    this.outlined = false,
  });

  final String name;
  final double size;

  /// Adds a white ring, used when avatars overlap.
  final bool outlined;

  static const _palette = [
    (AppColors.brandSoft, AppColors.brand),
    (Color(0xFFDDF4EC), Color(0xFF2F855A)),
    (Color(0xFFFFE9D6), Color(0xFFC05621)),
    (Color(0xFFE0ECFF), Color(0xFF2563EB)),
    (Color(0xFFFCE7F3), Color(0xFFBE185D)),
  ];

  /// "Sara Haddad" → "SH", "Candidate" → "C".
  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) =
        _palette[name.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: outlined ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Text(
          initialsOf(name),
          style: TextStyle(
            color: foreground,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// Overlapping avatars for up to [max] people, then a "+N" bubble. Screen
/// readers hear the full names.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.names,
    this.size = 28,
    this.max = 3,
  });

  final List<String> names;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();
    final shown = names.take(max).toList();
    final extra = names.length - shown.length;
    final step = size * 0.8;
    final count = shown.length + (extra > 0 ? 1 : 0);
    return Semantics(
      label: 'Assigned to ${names.join(', ')}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: size + step * (count - 1),
          height: size,
          child: Stack(
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: step * i,
                  child: InitialsAvatar(
                    name: shown[i],
                    size: size,
                    outlined: true,
                  ),
                ),
              if (extra > 0)
                Positioned(
                  left: step * shown.length,
                  child: Container(
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '+$extra',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: size * 0.34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
