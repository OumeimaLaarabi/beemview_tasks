import 'package:flutter/material.dart';

/// The design's outline icon set (24×24 grid, 1.8 stroke, round caps).
enum LineIcons { mail, lock, eye, eyeOff }

/// Draws one of [LineIcons] in the current icon color.
class LineIcon extends StatelessWidget {
  const LineIcon(this.icon, {super.key, this.size = 20, this.color});

  final LineIcons icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color =
        this.color ?? IconTheme.of(context).color ?? const Color(0xFF000000);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _LineIconPainter(icon, color),
      ),
    );
  }
}

class _LineIconPainter extends CustomPainter {
  _LineIconPainter(this.icon, this.color);

  final LineIcons icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_path(icon), paint);
  }

  static Path _path(LineIcons icon) => switch (icon) {
    LineIcons.mail =>
      Path()
        ..addRRect(_rrect(3, 5, 18, 14, 2))
        ..moveTo(3, 7)
        ..lineTo(12, 13)
        ..lineTo(21, 7),
    LineIcons.lock =>
      Path()
        ..addRRect(_rrect(4, 10, 16, 11, 2))
        ..moveTo(8, 10)
        ..lineTo(8, 7)
        ..arcToPoint(const Offset(16, 7), radius: const Radius.circular(4))
        ..lineTo(16, 10),
    LineIcons.eye => _eye(),
    LineIcons.eyeOff =>
      _eye()
        ..moveTo(4, 4)
        ..lineTo(20, 20),
  };

  static Path _eye() => Path()
    ..moveTo(2.5, 12)
    ..cubicTo(2.5, 12, 6, 6, 12, 6)
    ..cubicTo(18, 6, 21.5, 12, 21.5, 12)
    ..cubicTo(21.5, 12, 18, 18, 12, 18)
    ..cubicTo(6, 18, 2.5, 12, 2.5, 12)
    ..close()
    ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 2.5));

  static RRect _rrect(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  @override
  bool shouldRepaint(_LineIconPainter old) =>
      old.icon != icon || old.color != color;
}
