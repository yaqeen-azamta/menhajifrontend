// ════════════════════════════════════════════════════════════════════════════
// adaptive_quiz_result_screen.dart — Result screen for adaptive quiz
// ════════════════════════════════════════════════════════════════════════════
//
// Receives route `extra` map:
//   result       → AdaptiveQuizResult
//   difficulty   → int
//   focusSkills  → List<String>
//   lessonId     → String
//
// Displays:
//   • Score percentage (animated counter)
//   • Correct / incorrect / total stats
//   • Difficulty level badge
//   • Encouragement message based on score
//   • Updated skill performance (if any)
//   • Focus skill tip (if backend provided focus skills)
//   • "Try again" and "Go home" buttons
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_strings.dart';
import '../models/adaptive_quiz_models.dart';
import '../theme/theme.dart';
import '../widgets/fat_button.dart';

class AdaptiveQuizResultScreen extends StatefulWidget {
  const AdaptiveQuizResultScreen({
    super.key,
    required this.result,
    required this.difficulty,
    required this.focusSkills,
    required this.lessonId,
  });

  final AdaptiveQuizResult result;
  final int difficulty;
  final List<String> focusSkills;
  final String lessonId;

  @override
  State<AdaptiveQuizResultScreen> createState() =>
      _AdaptiveQuizResultScreenState();
}

class _AdaptiveQuizResultScreenState extends State<AdaptiveQuizResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _difficultyLabel(int d) {
    switch (d) {
      case 1:
        return 'سهل 🌱';
      case 2:
        return 'متوسط 📚';
      case 3:
        return 'متقدم 🔥';
      case 4:
        return 'صعب ⚡';
      case 5:
        return 'خبير 🏆';
      default:
        return 'مستوى $d';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final score = r.score;
    final encouragement = AppStrings.adaptiveResultEncouragement(score);
    final skillTip = AppStrings.adaptiveResultSkillTip(widget.focusSkills);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── header ──────────────────────────────────────────
            _ResultHeader(score: score, encouragement: encouragement, anim: _anim),

            // ── scrollable body ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    // Stats row
                    _StatsRow(result: r),
                    const SizedBox(height: 16),

                    // Difficulty badge
                    _InfoCard(
                      icon: '🎯',
                      title: AppStrings.adaptiveResultDifficulty,
                      value: _difficultyLabel(widget.difficulty),
                    ),
                    const SizedBox(height: 16),

                    // Focus skills tip
                    if (skillTip.isNotEmpty) ...[
                      _TipCard(tip: skillTip),
                      const SizedBox(height: 16),
                    ],

                    // Updated skills
                    if (r.updatedSkills.isNotEmpty) ...[
                      _SkillsSection(skills: r.updatedSkills),
                      const SizedBox(height: 16),
                    ],

                    // Per-question feedback
                    if (r.feedback.isNotEmpty) ...[
                      _FeedbackSection(
                        feedback: r.feedback,
                        questions: const [], // question texts not available here
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // ── action buttons ───────────────────────────────────
            _Actions(
              onRetry: () => context.go('/quiz/${widget.lessonId}'),
              onHome: () => context.go('/home'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HEADER — animated score arc + encouragement
// ─────────────────────────────────────────────────────────────

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.score,
    required this.encouragement,
    required this.anim,
  });

  final int score;
  final String encouragement;
  final Animation<double> anim;

  Color get _scoreColor {
    if (score >= 80) return const Color(0xFF2E7D32); // green
    if (score >= 60) return AppColors.primary;        // orange
    if (score >= 40) return AppColors.gold;           // gold
    return AppColors.danger;                          // red
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _scoreColor.withValues(alpha: 0.90),
            _scoreColor.withValues(alpha: 0.70),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: _scoreColor.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            AppStrings.adaptiveResultTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),

          // Animated score number
          AnimatedBuilder(
            animation: anim,
            builder: (_, child) {
              final displayed = (score * anim.value).round();
              return Text(
                '$displayed%',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          Text(
            encouragement,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STATS ROW — correct / incorrect / total
// ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.result});
  final AdaptiveQuizResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
            icon: '✅',
            label: AppStrings.adaptiveResultCorrect,
            value: '${result.correctCount}',
            color: const Color(0xFF2E7D32),
          ),
          Container(
            width: 1,
            height: 40,
            color: const Color(0xFFE5E5E5),
          ),
          _Stat(
            icon: '❌',
            label: AppStrings.adaptiveResultIncorrect,
            value: '${result.incorrectCount}',
            color: AppColors.danger,
          ),
          Container(
            width: 1,
            height: 40,
            color: const Color(0xFFE5E5E5),
          ),
          _Stat(
            icon: '📝',
            label: AppStrings.adaptiveResultTotal,
            value: '${result.totalCount}',
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// INFO CARD — single label/value row
// ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final String icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TIP CARD — focus skill encouragement
// ─────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});
  final String tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.40),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SKILLS SECTION — updated skill performance
// ─────────────────────────────────────────────────────────────

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({required this.skills});
  final List<SkillSummary> skills;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                AppStrings.adaptiveResultSkillsTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...skills.map((s) => _SkillRow(skill: s)),
        ],
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.skill});
  final SkillSummary skill;

  @override
  Widget build(BuildContext context) {
    final pct = (skill.mastery * 100).clamp(0.0, 100.0);
    final color = pct >= 80
        ? const Color(0xFF2E7D32)
        : pct >= 60
        ? AppColors.primary
        : pct >= 40
        ? AppColors.gold
        : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  skill.skillName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${pct.round()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 10,
              backgroundColor: const Color(0xFFE8DCC8),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FEEDBACK SECTION — per-question correct/incorrect results
// ─────────────────────────────────────────────────────────────

class _FeedbackSection extends StatelessWidget {
  const _FeedbackSection({
    required this.feedback,
    required this.questions,
  });

  final List<AdaptiveAnswerFeedback> feedback;
  final List<String> questions; // unused but kept for future question-text display

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('📋', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                'تفاصيل الإجابات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...feedback.map((f) => _FeedbackRow(item: f)),
        ],
      ),
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({required this.item});
  final AdaptiveAnswerFeedback item;

  @override
  Widget build(BuildContext context) {
    final correct = item.isCorrect;
    final bg =
        correct
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFEBEE);
    final border =
        correct ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A);
    final icon = correct ? '✅' : '❌';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  'السؤال ${item.questionIndex + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: correct
                        ? const Color(0xFF2E7D32)
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
            if (!correct && item.correctAnswer != null) ...[
              const SizedBox(height: 6),
              Text(
                AppStrings.feedbackCorrectAnswer(item.correctAnswer!),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
            if (item.explanation != null && item.explanation!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.explanation!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ACTION BUTTONS
// ─────────────────────────────────────────────────────────────

class _Actions extends StatelessWidget {
  const _Actions({required this.onRetry, required this.onHome});

  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FatButton(
            label: AppStrings.adaptiveResultRetry,
            color: FatColor.primary,
            onPressed: onRetry,
          ),
          const SizedBox(height: 10),
          FatButton(
            label: AppStrings.adaptiveResultHome,
            color: FatColor.secondary,
            onPressed: onHome,
          ),
        ],
      ),
    );
  }
}
