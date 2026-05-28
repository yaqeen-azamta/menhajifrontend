import 'package:flutter/material.dart';

/// Renders all user-drawn strokes with smooth Catmull-Rom–style curves.
class UserDrawingPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color strokeColor;
  final double strokeWidth;

  const UserDrawingPainter({
    required this.strokes,
    this.strokeColor = const Color(0xFF1565C0),
    this.strokeWidth = 6.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        // Single-tap dot
        canvas.drawCircle(
          stroke.first,
          strokeWidth / 2,
          Paint()..color = strokeColor,
        );
        continue;
      }
      canvas.drawPath(_smooth(stroke), paint);
    }
  }

  /// Builds a smooth path using quadratic Bézier midpoint averaging.
  Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 2) {
      path.lineTo(pts[1].dx, pts[1].dy);
      return path;
    }
    for (int i = 1; i < pts.length - 1; i++) {
      final mid = (pts[i] + pts[i + 1]) / 2;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(UserDrawingPainter old) =>
      old.strokes != strokes ||
      old.strokeColor != strokeColor ||
      old.strokeWidth != strokeWidth;
}