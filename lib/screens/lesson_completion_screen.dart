import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme.dart';
import '../widgets/fat_button.dart';

class LessonCompletionScreen extends StatefulWidget {
  const LessonCompletionScreen({super.key, required this.lessonId});
  final String lessonId;

  @override
  State<LessonCompletionScreen> createState() => _LessonCompletionScreenState();
}

class _LessonCompletionScreenState extends State<LessonCompletionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _scaleCtrl;
  late final AnimationController _slideCtrl;
  late final AnimationController _floatCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    // Staggered entrance: fade → character scale → content slide
    _fadeCtrl.forward();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _scaleCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _slideCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _scaleCtrl.dispose();
    _slideCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF9C4), Color(0xFFFFEFCA), Color(0xFFFEFDDF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ── Background floating stars ────────────────────────
              ..._buildFloatingStars(size),

              // ── Main content ─────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),

                      // Heading
                      const Text(
                        'أحسنت! 🌟',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'أنت تتقدم بشكل ممتاز!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 30),

                      // ── Animated character circle ─────────────────
                      ScaleTransition(
                        scale: _scaleAnim,
                        child: _CharacterCircle(),
                      ),

                      const SizedBox(height: 28),

                      // ── Badge row ─────────────────────────────────
                      SlideTransition(
                        position: _slideAnim,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Badge(
                              emoji: '⭐',
                              label: 'ممتاز!',
                              bgColor: Color(0xFFFFF3CD),
                              borderColor: Color(0xFFFFD600),
                            ),
                            SizedBox(width: 10),
                            _Badge(
                              emoji: '🌟',
                              label: 'بطل التعلم',
                              bgColor: Color(0xFFD4F4DD),
                              borderColor: Color(0xFF43A047),
                            ),
                            SizedBox(width: 10),
                            _Badge(
                              emoji: '🎉',
                              label: 'أحسنت',
                              bgColor: Color(0xFFFFE3D4),
                              borderColor: Color(0xFFFF6B35),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Completion message card ────────────────────
                      SlideTransition(
                        position: _slideAnim,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(26),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFFE8DCC8),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Column(
                            children: [
                              Text(
                                'لقد أكملت الدرس بنجاح! 🎓',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'تعلمت شيئاً جديداً اليوم.',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 12),
                              _ReadyChip(),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Buttons ───────────────────────────────────
                      SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          children: [
                            FatButton(
                              label: '📖 ابدأ الاختبار',
                              onPressed: () =>
                                  context.go('/quiz/${widget.lessonId}'),
                            ),
                            const SizedBox(height: 14),
                            FatButton(
                              label: '↩ رجوع إلى الدروس',
                              color: FatColor.secondary,
                              onPressed: () => context.go('/home'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFloatingStars(Size size) {
    final rng = Random(42);
    const emojis = ['⭐', '✨', '💫', '🌟'];
    return List.generate(12, (i) {
      final x = rng.nextDouble() * (size.width - 36);
      final y = rng.nextDouble() * (size.height - 36);
      final phase = rng.nextDouble();
      final fontSize = 14.0 + rng.nextDouble() * 14.0;
      return _FloatingStar(
        x: x,
        baseY: y,
        emoji: emojis[i % emojis.length],
        controller: _floatCtrl,
        phase: phase,
        size: fontSize,
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHARACTER CIRCLE
// ─────────────────────────────────────────────────────────────────────────────

class _CharacterCircle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: 188,
          height: 188,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold.withValues(alpha: 0.18),
          ),
        ),
        // Main circle
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFED80),
            border: Border.all(color: AppColors.gold, width: 5),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.45),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text('🏆', style: TextStyle(fontSize: 82)),
        ),
        // Decorative mini stars around the circle
        ..._miniStars(),
      ],
    );
  }

  static List<Widget> _miniStars() {
    const items = [
      (angle: 0.0, emoji: '⭐'),
      (angle: 60.0, emoji: '✨'),
      (angle: 120.0, emoji: '🌟'),
      (angle: 180.0, emoji: '⭐'),
      (angle: 240.0, emoji: '✨'),
      (angle: 300.0, emoji: '💫'),
    ];
    return items.map((item) {
      final rad = item.angle * pi / 180;
      const r = 105.0;
      return Transform.translate(
        offset: Offset(cos(rad) * r, sin(rad) * r),
        child: Text(item.emoji, style: const TextStyle(fontSize: 18)),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READY CHIP — "هل أنت مستعد للاختبار؟ 🚀"
// ─────────────────────────────────────────────────────────────────────────────

class _ReadyChip extends StatelessWidget {
  const _ReadyChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.30),
          width: 1.5,
        ),
      ),
      child: const Text(
        'هل أنت مستعد للاختبار؟ 🚀',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: AppColors.primary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE — colored pill chip with emoji and label
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({
    required this.emoji,
    required this.label,
    required this.bgColor,
    required this.borderColor,
  });

  final String emoji;
  final String label;
  final Color bgColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING STAR — single bobbing emoji anchored at (x, baseY)
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingStar extends StatelessWidget {
  const _FloatingStar({
    required this.x,
    required this.baseY,
    required this.emoji,
    required this.controller,
    required this.phase,
    required this.size,
  });

  final double x;
  final double baseY;
  final String emoji;
  final Animation<double> controller;
  final double phase;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final t = ((controller.value + phase) % 1.0) * 2 * pi;
        final dy = sin(t) * 11.0;
        final opacity = (0.25 + 0.40 * (sin(t + pi / 2) * 0.5 + 0.5))
            .clamp(0.0, 1.0);
        return Positioned(
          left: x,
          top: baseY + dy,
          child: Opacity(
            opacity: opacity,
            child: Text(emoji, style: TextStyle(fontSize: size)),
          ),
        );
      },
    );
  }
}
