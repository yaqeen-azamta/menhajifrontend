import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key});
  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  late List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _pieces = List.generate(36, (i) {
      return _Piece(
        x: _rng.nextDouble(),
        speed: 0.6 + _rng.nextDouble() * 0.8,
        rot: _rng.nextDouble() * 6.28,
        color: _palette[_rng.nextInt(_palette.length)],
        delay: _rng.nextDouble(),
      );
    });
  }

  static const _palette = [
    Color(0xFF58CC02),
    Color(0xFF1CB0F6),
    Color(0xFFFFC800),
    Color(0xFFFF9600),
    Color(0xFFCE82FF),
    Color(0xFFFF4B4B),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _ctrl.value),
        ),
      ),
    );
  }
}

class _Piece {
  final double x, speed, rot, delay;
  final Color color;
  _Piece({
    required this.x,
    required this.speed,
    required this.rot,
    required this.color,
    required this.delay,
  });
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final progress = ((t + p.delay) * p.speed) % 1.0;
      final dx = p.x * size.width;
      final dy = progress * (size.height + 60) - 30;
      paint.color = p.color;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rot + progress * 6.28);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-5, -8, 10, 14),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}
