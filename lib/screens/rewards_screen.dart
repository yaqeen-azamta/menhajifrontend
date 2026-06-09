import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/avatar_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/parent_progress_service.dart';
import '../theme/theme.dart';
import '../widgets/fat_button.dart';

// ─────────────────────────────────────────────────────────────
// Level system
// ─────────────────────────────────────────────────────────────
class _LevelDef {
  final int level;
  final String title;
  final String emoji;
  final int minPts;
  final int maxPts;

  const _LevelDef(
    this.level,
    this.title,
    this.emoji,
    this.minPts,
    this.maxPts,
  );

  double progress(int pts) {
    final span = maxPts - minPts;
    if (span <= 0) return 1.0;
    return ((pts - minPts) / span).clamp(0.0, 1.0);
  }

  int remaining(int pts) => (maxPts - pts).clamp(0, maxPts);
  bool get isMax => level == 6;
}

const _kLevels = [
  _LevelDef(1, 'مبتدئ', '🌱', 0, 500),
  _LevelDef(2, 'مستكشف', '🔍', 500, 1000),
  _LevelDef(3, 'باحث', '📚', 1000, 1500),
  _LevelDef(4, 'بطل', '🏆', 1500, 2000),
  _LevelDef(5, 'خبير', '🌟', 2000, 2500),
  _LevelDef(6, 'أسطورة', '👑', 2500, 2500),
];

_LevelDef _levelOf(int pts) {
  for (final l in _kLevels.reversed) {
    if (pts >= l.minPts) return l;
  }
  return _kLevels.first;
}

// ─────────────────────────────────────────────────────────────
// Achievement badges (computed client-side)
// ─────────────────────────────────────────────────────────────
class _BadgeDef {
  final String emoji;
  final String title;
  final String desc;
  final bool unlocked;
  const _BadgeDef(this.emoji, this.title, this.desc, this.unlocked);
}

List<_BadgeDef> _buildBadges(ProgressSummaryModel? p, int quizPct) => [
  _BadgeDef('👣', 'أول خطوة',       'أكمل أول درس',          (p?.completedLessons ?? 0) >= 1),
  _BadgeDef('💯', 'علامة كاملة',    'احصل على 100%',          quizPct == 100),
  _BadgeDef('📖', 'قارئ نشيط',      'أكمل 10 دروس',          (p?.completedLessons ?? 0) >= 10),
  _BadgeDef('🔥', 'أسبوع متواصل',   '7 أيام متتالية',         (p?.currentStreak ?? 0) >= 7),
  _BadgeDef('⚡', 'متعلم سريع',     'أكمل 5 دروس',           (p?.completedLessons ?? 0) >= 5),
  _BadgeDef('⭐', 'جامع النقاط',    'اكسب 500 نقطة',         (p?.totalPoints ?? 0) >= 500),
];

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({
    super.key,
    this.stars = 0,
    this.xp = 0,
    this.correct = 0,
    this.total = 0,
    this.lessonId,
    this.isTab = false,
  });

  final int stars;
  final int xp;
  final int correct;
  final int total;
  final String? lessonId;
  // When true the screen is embedded as a nav tab — hides the back arrow
  // and the bottom "return home" button which would conflict with the nav bar.
  final bool isTab;

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with TickerProviderStateMixin {
  // ── data ──────────────────────────────────────────────────
  ProgressSummaryModel? _progress;
  String _studentName = '';
  String? _savedAvatarId;
  bool _loading = true;

  // Avatars that crossed their unlock threshold since the last visit.
  // Populated in _load() and consumed by _scheduleUnlockNotifications().
  List<AvatarDef> _newlyUnlocked = [];

  // ── animation controllers ──────────────────────────────────
  late final AnimationController _entryCtrl;
  late final AnimationController _arcCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _arcCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _load();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _arcCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getInt('active_student_id');
      _studentName = prefs.getString('active_student_name') ?? '';
      _savedAvatarId = prefs.getString('active_student_avatar');

      if (studentId != null) {
        // Read cached points BEFORE fetching so we can diff for new unlocks.
        final prevPts = prefs.getInt('cached_pts_$studentId') ?? 0;

        _progress = await ProgressService.instance.getSummary(studentId);

        final newPts = _progress?.totalPoints ?? 0;
        _newlyUnlocked = AvatarConfig.newlyUnlocked(prevPts, newPts);
        await prefs.setInt('cached_pts_$studentId', newPts);
      }
    } on ApiException catch (_) {
      // degrade gracefully — show zeros
    } catch (_) {
      // same
    }

    if (!mounted) return;
    setState(() => _loading = false);
    _entryCtrl.forward();
    _scheduleUnlockNotifications();
    await Future.delayed(const Duration(milliseconds: 280));
    if (mounted) _arcCtrl.forward();
  }

  // ── Avatar unlock notifications ───────────────────────────
  //
  // Staggered SnackBars — one per newly unlocked avatar.
  // The delay lets the entry animation finish before the first one appears.

  void _scheduleUnlockNotifications() {
    for (var i = 0; i < _newlyUnlocked.length; i++) {
      final av = _newlyUnlocked[i];
      Future.delayed(Duration(milliseconds: 900 + i * 1600), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppStrings.avatarNewUnlock(av.name),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            backgroundColor: AppColors.gold,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      });
    }
  }

  // ── Avatar selection ──────────────────────────────────────

  Future<void> _onAvatarSelected(String avatarId) async {
    if (_savedAvatarId == avatarId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            AppStrings.avatarAlreadyActive,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.textSecondary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Optimistic update — reflect immediately in the UI.
    setState(() => _savedAvatarId = avatarId);

    // Persist locally + sync to backend (fire-and-forget).
    await AuthService.instance.updateAvatar(avatarId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            AppStrings.avatarChanged,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final p = _progress;
    final pts = p?.totalPoints ?? 0;
    final streak = p?.currentStreak ?? 0;
    final lv = _levelOf(pts);
    final av = AvatarConfig.resolve(_savedAvatarId);
    final hasQuiz = widget.total > 0;
    final qPct =
        hasQuiz ? (widget.correct / widget.total * 100).round() : 0;
    final badges = _buildBadges(p, qPct);
    final unlockedCount = badges.where((b) => b.unlocked).length;

    final entryFade =
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    final entrySlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic),
        );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── top bar ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  if (!widget.isTab)
                    IconButton(
                      onPressed: _back,
                      icon: const Icon(Icons.chevron_left, size: 28),
                    )
                  else
                    const SizedBox(width: 48),
                  const Expanded(
                    child: Text(
                      AppStrings.rewardsYourRewards,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── scrollable content ────────────────────────────
            Expanded(
              child: SlideTransition(
                position: entrySlide,
                child: FadeTransition(
                  opacity: entryFade,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    child: Column(
                      children: [
                        // Post-quiz result banner
                        if (hasQuiz) ...[
                          _QuizBanner(
                            stars: widget.stars,
                            xp: widget.xp,
                            correct: widget.correct,
                            total: widget.total,
                            percent: qPct,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Student profile card
                        _StudentCard(
                          avatarDef: av,
                          name: _studentName.isNotEmpty
                              ? _studentName
                              : 'طالب',
                          pts: pts,
                          lv: lv,
                          unlockedCount: unlockedCount,
                          totalBadges: badges.length,
                        ),
                        const SizedBox(height: 16),

                        // Level progress
                        _LevelCard(lv: lv, pts: pts, arcAnim: _arcCtrl),
                        const SizedBox(height: 16),

                        // Daily streak
                        _StreakCard(streak: streak),
                        const SizedBox(height: 16),

                        // Achievements grid
                        _AchievementsSection(badges: badges),
                        const SizedBox(height: 16),

                        // Avatar collection
                        _AvatarsCard(
                          currentId: av.id,
                          pts: pts,
                          onSelect: _onAvatarSelected,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.isTab
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: FatButton(
                  label: AppStrings.rewardsBackHome,
                  onPressed: _back,
                ),
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Post-quiz result banner
// ─────────────────────────────────────────────────────────────
class _QuizBanner extends StatelessWidget {
  const _QuizBanner({
    required this.stars,
    required this.xp,
    required this.correct,
    required this.total,
    required this.percent,
  });
  final int stars, xp, correct, total, percent;

  @override
  Widget build(BuildContext context) {
    final starStr = stars > 0 ? '⭐' * stars.clamp(1, 3) : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE87F24), Color(0xFFFFC81E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33E87F24),
            offset: Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 4),
          const Text(
            AppStrings.rewardsComplete,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          if (starStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(starStr, style: const TextStyle(fontSize: 30)),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BannerStat(
                  label: AppStrings.rewardsCorrect,
                  value: '$correct/$total',
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                _BannerStat(
                  label: AppStrings.rewardsScore,
                  value: '$percent%',
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                _BannerStat(
                  label: AppStrings.rewardsXp,
                  value: '+$xp ⭐',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Student profile card
// ─────────────────────────────────────────────────────────────
class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.avatarDef,
    required this.name,
    required this.pts,
    required this.lv,
    required this.unlockedCount,
    required this.totalBadges,
  });
  final AvatarDef avatarDef;
  final String name;
  final int pts;
  final _LevelDef lv;
  final int unlockedCount, totalBadges;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF73A5CA), Color(0xFF4A7FA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3373A5CA),
            offset: Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              avatarDef.emoji,
              style: const TextStyle(fontSize: 42),
            ),
          ),
          const SizedBox(width: 16),

          // Info column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(lv.emoji, style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 4),
                    Text(
                      lv.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _Chip(icon: '⭐', label: '$pts نقطة'),
                    _Chip(
                      icon: '🏅',
                      label: '$unlockedCount/$totalBadges شارة',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final String icon, label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Level progress card
// ─────────────────────────────────────────────────────────────
class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.lv,
    required this.pts,
    required this.arcAnim,
  });
  final _LevelDef lv;
  final int pts;
  final AnimationController arcAnim;

  @override
  Widget build(BuildContext context) {
    final prog = lv.progress(pts);
    final anim = CurvedAnimation(parent: arcAnim, curve: Curves.easeOutCubic);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
                'مستوى التقدم',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular arc
              _CircularArc(levelDef: lv, pts: pts, anim: anim),
              const SizedBox(width: 20),
              // Linear bar + text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المستوى ${lv.level}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      lv.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: anim,
                      builder: (ctx, child) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: prog * anim.value,
                          minHeight: 14,
                          backgroundColor: const Color(0xFFE8DCC8),
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    lv.isMax
                        ? const Text(
                            '🎉 وصلت لأعلى مستوى!',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          )
                        : Text(
                            '${lv.remaining(pts)} نقطة للمستوى التالي',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircularArc extends StatelessWidget {
  const _CircularArc({
    required this.levelDef,
    required this.pts,
    required this.anim,
  });
  final _LevelDef levelDef;
  final int pts;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    final prog = levelDef.progress(pts);
    return AnimatedBuilder(
      animation: anim,
      builder: (ctx, child) {
        final v = prog * anim.value;
        return SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(110, 110),
                painter: _ArcPainter(progress: v),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    levelDef.emoji,
                    style: const TextStyle(fontSize: 30),
                  ),
                  Text(
                    '${(v * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  const _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 10;
    const sw = 12.0;
    // Arc from ~7:30 o'clock sweeping 270° clockwise, gap at bottom
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      sweep,
      false,
      Paint()
        ..color = const Color(0xFFE8DCC8)
        ..strokeWidth = sw
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        sweep * progress,
        false,
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = sw
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────
// Daily streak card
// ─────────────────────────────────────────────────────────────
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});
  final int streak;

  String get _motiv {
    if (streak == 0) return 'ابدأ اليوم! 💪';
    if (streak < 3) return 'بداية رائعة! 🌟';
    if (streak < 7) return 'أنت تتقدم بشكل رائع!';
    if (streak < 14) return 'حافظ على هذا الإيقاع!';
    return 'لا يمكن إيقافك! 🏆';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9600), Color(0xFFFF5722)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33FF9600),
            offset: Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 52)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$streak يوم متتالي',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                _motiv,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Achievements section
// ─────────────────────────────────────────────────────────────
class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection({required this.badges});
  final List<_BadgeDef> badges;

  @override
  Widget build(BuildContext context) {
    final unlocked = badges.where((b) => b.unlocked).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🏅', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text(
              'شاراتي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            Text(
              '$unlocked/${badges.length}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final w = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: badges
                  .map((b) => SizedBox(width: w, child: _BadgeCard(badge: b)))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});
  final _BadgeDef badge;

  @override
  Widget build(BuildContext context) {
    final ok = badge.unlocked;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? Colors.white : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ok ? AppColors.gold : const Color(0xFFE0E0E0),
          width: ok ? 2 : 1,
        ),
        boxShadow: ok
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok
                  ? const Color(0xFFFFF8E1)
                  : const Color(0xFFEEEEEE),
            ),
            alignment: Alignment.center,
            child: ok
                ? Text(badge.emoji, style: const TextStyle(fontSize: 22))
                : const Text('🔒', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ok
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  badge.desc,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ok
                        ? AppColors.textSecondary
                        : const Color(0xFFBBBBBB),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Avatar collection card
// ─────────────────────────────────────────────────────────────
class _AvatarsCard extends StatelessWidget {
  const _AvatarsCard({
    required this.currentId,
    required this.pts,
    required this.onSelect,
  });
  final String currentId;
  final int pts;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎭', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                'مجموعة الشخصيات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            AppStrings.avatarSelectHint,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: AvatarConfig.all
                .map(
                  (av) => _AvatarTile(
                    av: av,
                    unlocked: av.isUnlocked(pts),
                    isCurrent: av.id == currentId,
                    onSelect: onSelect,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.av,
    required this.unlocked,
    required this.isCurrent,
    required this.onSelect,
  });
  final AvatarDef av;
  final bool unlocked, isCurrent;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!unlocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.avatarUnlockRequires(av.name, av.unlockPoints),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: const Color(0xFF5C5C5C),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else {
          onSelect(av.id);
        }
      },
      child: Tooltip(
        message: unlocked
            ? av.name
            : AppStrings.avatarUnlockRequires(av.name, av.unlockPoints),
        child: SizedBox(
          width: 58,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked
                      ? (isCurrent
                          ? const Color(0xFFFFF3E0)
                          : const Color(0xFFFAF8EE))
                      : const Color(0xFFEEEEEE),
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.primary
                        : unlocked
                        ? const Color(0xFFE8DCC8)
                        : const Color(0xFFDDDDDD),
                    width: isCurrent ? 2.5 : 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: unlocked
                    ? Text(av.emoji, style: const TextStyle(fontSize: 26))
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: 0.25,
                            child: Text(
                              av.emoji,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                          const Positioned(
                            bottom: 0,
                            right: 0,
                            child: Text(
                              '🔒',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 3),
              Text(
                unlocked ? av.name : AppStrings.avatarRequiredPoints(av.unlockPoints),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: unlocked
                      ? (isCurrent ? AppColors.primary : AppColors.textSecondary)
                      : const Color(0xFFBBBBBB),
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
