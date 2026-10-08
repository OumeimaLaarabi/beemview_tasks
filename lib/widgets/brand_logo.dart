import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// The BeemView mark (three slanted bars) with an optional wordmark.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.compact = false});

  /// Mark only, on a translucent tile (for app bars on the hero gradient).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final side = compact ? 34.0 : 30.0;
    final mark = Container(
      width: side,
      height: side,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: compact ? null : AppColors.logoGradient,
        color: compact ? Colors.white.withValues(alpha: 0.15) : null,
        border: Border.all(
          color: Colors.white.withValues(alpha: compact ? 0.16 : 0.18),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Bar(height: 8, opacity: 0.7),
          SizedBox(width: 2),
          _Bar(height: 15, opacity: 1),
          SizedBox(width: 2),
          _Bar(height: 11, opacity: 0.86),
        ],
      ),
    );
    if (compact) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        const Text(
          'BeemView',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.opacity});

  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.skewX(-9 * math.pi / 180),
      child: Container(
        width: 4,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
