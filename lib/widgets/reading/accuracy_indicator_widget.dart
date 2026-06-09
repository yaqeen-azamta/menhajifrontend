import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/theme.dart';

// ─────────────────────────────────────────────────────────────
// AccuracyIndicatorWidget
//
// Reusable animated circular arc that displays a reading accuracy
// percentage (0–100). The arc color and grade label change based
// on the score tier:
//   ≥ 80% → green   "ممتاز! 🌟"
//   ≥ 60% → orange  "جيد! 👍"
//    < 60% → red     "يحتاج تحسين 💪"
//
// Future extension: accept a [pronunciationScore] alongside
// [accuracy] to show a dual-ring indicator for Phase 2.
// ─────────────────────────────────────────────────────────────

class AccuracyIndicatorWidget extends StatefulWidget {
  const AccuracyIndicatorWidget({
    super.key,
    required this.accuracy,
    this.animate = true,
    this.size = 160.0,
  });

  final int accuracy; // 0–100
  final bool animate;
  final double size;

  @override
  State<AccuracyIndicatorWidget> createState() =>
      _AccuracyIndicatorWidgetState();
}

class _AccuracyIndicatorWidgetState extends State<AccuracyIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.animate) _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Color tier helpers ────────────────────────────────────
  //
  // Four tiers matching PronunciationService.feedbackFor() thresholds:
  //   ≥ 90 → green   "ممتاز! 🌟"
  //   ≥ 70 → blue    "جيد! 👍"
  //   ≥ 50 → orange  "يحتاج تحسين 💪"
  //    < 50 → red     "حاول مرة أخرى ⚡"

  Color get _arcColor {
    if (widget.accuracy >= 90) return const Color(0xFF2E7D32); // dark green
    if (widget.accuracy >= 70) return const Color(0xFF1565C0); // dark blue
    if (widget.accuracy >= 50) return const Color(0xFFE65100); // dark orange
    return const Color(0xFFC62828);                             // dark red
  }

  Color get _bgColor {
    if (widget.accuracy >= 90) return const Color(0xFFE8F5E9); // light green
    if (widget.accuracy >= 70) return const Color(0xFFE3F2FD); // light blue
    if (widget.accuracy >= 50) return const Color(0xFFFFF3E0); // light orange
    return const Color(0xFFFFEBEE);                             // light red
  }

  String get _gradeLabel {
    if (widget.accuracy >= 90) return AppStrings.readingGradeExcellent;
    if (widget.accuracy >= 70) return AppStrings.readingGradeGood;
    if (widget.accuracy >= 50) return AppStrings.readingGradeNeedsWork;
    return AppStrings.readingGradeTryAgain;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (widget.accuracy / 100.0).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Arc circle ────────────────────────────────────
        AnimatedBuilder(
          animation: _anim,
          builder: (_, _) {
            final animatedProgress = widget.animate
                ? progress * _anim.value
                : progress;
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle tint
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _bgColor,
                    ),
                  ),
                  // Arc painter
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _AccuracyArcPainter(
                      progress: animatedProgress,
                      arcColor: _arcColor,
                    ),
                  ),
                  // Centre text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.readingAccuracyPct(
                          (animatedProgress * 100).round(),
                        ),
                        style: TextStyle(
                          fontSize: widget.size * 0.22,
                          fontWeight: FontWeight.w900,
                          color: _arcColor,
                          fontFamily: 'Nunito',
                        ),
                      ),
                      Text(
                        AppStrings.readingAccuracyLabel,
                        style: TextStyle(
                          fontSize: widget.size * 0.09,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          fontFamily: 'Nunito',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // ── Grade label ───────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Container(
            key: ValueKey(_gradeLabel),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _arcColor.withValues(alpha: 0.35), width: 2),
            ),
            child: Text(
              _gradeLabel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _arcColor,
                fontFamily: 'Nunito',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Arc CustomPainter
//
// Draws a 270° arc (same geometry as _ArcPainter in rewards_screen)
// starting at 7:30 o'clock sweeping clockwise.
// ─────────────────────────────────────────────────────────────

class _AccuracyArcPainter extends CustomPainter {
  final double progress; // 0.0–1.0
  final Color arcColor;

  const _AccuracyArcPainter({required this.progress, required this.arcColor});

  static const _startAngle = math.pi * 0.75; // 135° (7:30 o'clock)
  static const _sweepFull = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const strokeWidth = 13.0;

    final trackPaint = Paint()
      ..color = const Color(0xFFE8DCC8)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = arcColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (background ring)
    canvas.drawArc(rect, _startAngle, _sweepFull, false, trackPaint);

    // Fill (progress)
    if (progress > 0) {
      canvas.drawArc(
        rect,
        _startAngle,
        _sweepFull * progress,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_AccuracyArcPainter old) =>
      old.progress != progress || old.arcColor != arcColor;
}
