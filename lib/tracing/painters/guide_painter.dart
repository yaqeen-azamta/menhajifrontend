import 'package:flutter/material.dart';

import '../models/tracing_question.dart';

/// Simple worksheet background painter.
/// Draws:
///   • cream background
///   • horizontal ruled lines
///
/// No guide paths or arrows anymore.
class GuidePainter extends CustomPainter {
  final TracingQuestion question;

  const GuidePainter({required this.question});

  // ── Colors ────────────────────────────────────────────────────────────────

  static const _bgColor = Color(0xFFFEFDDF);

  static const _ruleColor = Color(0xFFB3CEDE);

  // ── Main paint ────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    _drawRuledLines(canvas, size);
  }

  // ── Background ────────────────────────────────────────────────────────────

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),

      Paint()..color = _bgColor,
    );
  }

  // ── Worksheet ruled lines ────────────────────────────────────────────────

  void _drawRuledLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _ruleColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final frac in const [0.12, 0.50, 0.88]) {
      final y = size.height * frac;

      canvas.drawLine(
        Offset(size.width * 0.04, y),

        Offset(size.width * 0.96, y),

        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GuidePainter oldDelegate) => false;
}
