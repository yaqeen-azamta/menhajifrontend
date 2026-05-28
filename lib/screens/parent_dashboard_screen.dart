import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/parent_progress_service.dart';
import '../theme/theme.dart';
import '../models/avatar_config.dart';

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────
class ParentDashboardScreen extends StatefulWidget {
  final ParentDashboardModel dashboard;
  final int initialChildIndex;

  const ParentDashboardScreen({
    super.key,
    required this.dashboard,
    this.initialChildIndex = 0,
  });

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen>
    with TickerProviderStateMixin {
  late int _selectedIndex;
  ChildDetailModel? _detail;
  bool _loading = true;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialChildIndex.clamp(
      0,
      widget.dashboard.children.isEmpty
          ? 0
          : widget.dashboard.children.length - 1,
    );
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.dashboard.children.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      await AuthService.instance.switchToParent();
      final child = widget.dashboard.children[_selectedIndex];
      final detail = await ParentService.instance.getChildDetail(
        child.studentId,
      );
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
        _animCtrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  void _selectChild(int index) {
    if (index == _selectedIndex && _detail != null) return;
    _animCtrl.reset();
    setState(() {
      _selectedIndex = index;
      _detail = null;
    });
    _load();
  }

  ChildSummaryModel get _currentChild =>
      widget.dashboard.children[_selectedIndex];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F3E8),
        body: Column(
          children: [
            _GradientHeader(
              onBack: () => Navigator.pop(context),
              onRefresh: _load,
            ),
            if (widget.dashboard.children.length > 1)
              _ChildTabBar(
                children: widget.dashboard.children,
                selectedIndex: _selectedIndex,
                onSelect: _selectChild,
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: widget.dashboard.children.isEmpty
                    ? const _EmptyState(key: ValueKey('empty'))
                    : _loading
                    ? const _LoadingState(key: ValueKey('loading'))
                    : _error != null
                    ? _ErrorState(
                        key: const ValueKey('error'),
                        message: _error!,
                        onRetry: _load,
                      )
                    : _ContentScroll(
                        key: ValueKey('content-$_selectedIndex'),
                        child: _currentChild,
                        detail: _detail!,
                        animation: _anim,
                        onRefresh: _load,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Gradient header
// ─────────────────────────────────────────────────────────────
class _GradientHeader extends StatelessWidget {
  const _GradientHeader({required this.onBack, required this.onRefresh});
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE87F24), Color(0xFFFFC81E)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const Expanded(
                child: Column(
                  children: [
                    Text(
                      'لوحة تقدم أطفالي',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'تابع رحلة تعلّم طفلك',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Child tab bar (only shown when > 1 child)
// ─────────────────────────────────────────────────────────────
class _ChildTabBar extends StatelessWidget {
  const _ChildTabBar({
    required this.children,
    required this.selectedIndex,
    required this.onSelect,
  });
  final List<ChildSummaryModel> children;
  final int selectedIndex;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFD4701A), Color(0xFFE8A800)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: children.length,
        itemBuilder: (_, i) {
          final c = children[i];
          final selected = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.white24,
                borderRadius: BorderRadius.circular(24),
                boxShadow: selected
                    ? [
                        const BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AvatarConfig.resolve(c.avatarId).emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.fullName.split(' ').first,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: selected ? AppColors.primary : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Main scrollable content
// ─────────────────────────────────────────────────────────────
class _ContentScroll extends StatelessWidget {
  const _ContentScroll({
    super.key,
    required this.child,
    required this.detail,
    required this.animation,
    required this.onRefresh,
  });
  final ChildSummaryModel child;
  final ChildDetailModel detail;
  final Animation<double> animation;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          _ChildInfoCard(child: child, detail: detail),
          const SizedBox(height: 16),
          _ProgressOverviewCard(detail: detail, animation: animation),
          const SizedBox(height: 16),
          _LastActivityCard(child: child, detail: detail),
          if (detail.subjectBreakdown.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SubjectProgressSection(detail: detail, animation: animation),
          ],
          const SizedBox(height: 16),
          _AchievementsCard(child: child, detail: detail),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 1. Child info hero card
// ─────────────────────────────────────────────────────────────
class _ChildInfoCard extends StatelessWidget {
  const _ChildInfoCard({required this.child, required this.detail});
  final ChildSummaryModel child;
  final ChildDetailModel detail;

  static const _gradeNames = [
    'الأول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الخامس',
    'السادس',
  ];

  String get _gradeLabel {
    final g = detail.gradeLevel;
    if (g >= 1 && g <= 6) return 'الصف ${_gradeNames[g - 1]}';
    return 'الصف $g';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF73A5CA), Color(0xFF4D8AB5)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.38),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar circle
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              AvatarConfig.resolve(child.avatarId).emoji,
              style: const TextStyle(fontSize: 54),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            detail.fullName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _gradeLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatChip(
                emoji: '⭐',
                value: '${detail.totalPoints}',
                label: 'نجمة',
              ),
              const SizedBox(width: 12),
              _StatChip(
                emoji: '🔥',
                value: '${detail.currentStreak}',
                label: 'يوم',
              ),
              const SizedBox(width: 12),
              _StatChip(
                emoji: '✅',
                value: '${detail.lessonsCompleted}',
                label: 'درس',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.emoji,
    required this.value,
    required this.label,
  });
  final String emoji, value, label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white30, width: 1),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 2. Progress overview card
// ─────────────────────────────────────────────────────────────
class _ProgressOverviewCard extends StatelessWidget {
  const _ProgressOverviewCard({required this.detail, required this.animation});
  final ChildDetailModel detail;
  final Animation<double> animation;

  int get _total => detail.effectiveTotalLessons;
  int get _done => detail.lessonsCompleted;
  double get _completionRatio => _total > 0 ? _done / _total : 0;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(emoji: '📊', label: 'نظرة عامة على التقدم'),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$_done',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                          TextSpan(
                            text: ' / $_total',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'درس مكتمل',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: animation,
                builder: (ctx, snap) => _CircularPercent(
                  value: _completionRatio * animation.value,
                  color: AppColors.primary,
                  size: 82,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Animated linear bar
          AnimatedBuilder(
            animation: animation,
            builder: (ctx, snap) {
              final v = _completionRatio * animation.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 16,
                      backgroundColor: const Color(0xFFF0EDE0),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(v * 100).round()}% اكتمل',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _InfoChip(
                emoji: '🎯',
                label: 'إتقان',
                value: '${detail.overallMastery.round()}%',
                color: AppColors.gold,
              ),
              const SizedBox(width: 10),
              _InfoChip(
                emoji: '⏳',
                label: 'جارٍ',
                value: '${detail.lessonsInProgress}',
                color: AppColors.secondary,
              ),
              if (detail.totalQuizzesTaken > 0) ...[
                const SizedBox(width: 10),
                _InfoChip(
                  emoji: '📝',
                  label: 'اختبار',
                  value: '${detail.totalQuizzesTaken}',
                  color: AppColors.purple,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 3. Last activity card
// ─────────────────────────────────────────────────────────────
class _LastActivityCard extends StatelessWidget {
  const _LastActivityCard({required this.child, required this.detail});
  final ChildSummaryModel child;
  final ChildDetailModel detail;

  @override
  Widget build(BuildContext context) {
    final hasQuiz = detail.totalQuizzesTaken > 0;
    final hasProgress =
        detail.lessonsCompleted > 0 || detail.lessonsInProgress > 0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(emoji: '⚡', label: 'آخر نشاط'),
          const SizedBox(height: 14),
          if (!hasProgress && !hasQuiz)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'لا يوجد نشاط بعد — شجّع طفلك على بدء أول درس! 🚀',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else ...[
            if (detail.lessonsCompleted > 0)
              _ActivityRow(
                icon: '📚',
                color: AppColors.secondary,
                title: 'الدروس المكتملة',
                subtitle:
                    '${detail.lessonsCompleted} درس من أصل ${detail.effectiveTotalLessons}',
              ),
            if (detail.lessonsInProgress > 0) ...[
              const SizedBox(height: 10),
              _ActivityRow(
                icon: '🔄',
                color: AppColors.primary,
                title: 'دروس جارٍ العمل عليها',
                subtitle: '${detail.lessonsInProgress} درس في التقدم',
              ),
            ],
            if (hasQuiz) ...[
              const SizedBox(height: 10),
              _ActivityRow(
                icon: '📝',
                color: AppColors.purple,
                title: 'آخر نتيجة اختبار',
                subtitle:
                    '${detail.averageQuizScore.toStringAsFixed(1)}% متوسط الدرجات (${detail.totalQuizzesTaken} اختبار)',
              ),
            ],
            const SizedBox(height: 10),
            _ActivityRow(
              icon: '🎯',
              color: AppColors.gold,
              title: 'مستوى الإتقان العام',
              subtitle: '${detail.overallMastery.toStringAsFixed(1)}%',
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
  final String icon, title, subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(icon, style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 4. Subject progress section
// ─────────────────────────────────────────────────────────────
class _SubjectProgressSection extends StatelessWidget {
  const _SubjectProgressSection({
    required this.detail,
    required this.animation,
  });
  final ChildDetailModel detail;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SectionTitle(emoji: '📖', label: 'تقدم المواد الدراسية'),
        ),
        ...detail.subjectBreakdown.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SubjectCard(
              subject: e.value,
              animation: animation,
              delay: e.key * 0.12,
            ),
          ),
        ),
      ],
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.animation,
    required this.delay,
  });
  final SubjectMasteryModel subject;
  final Animation<double> animation;
  final double delay;

  @override
  Widget build(BuildContext context) {
    final (bgColor, shadowColor) = SubjectColors.of(subject.key);
    final ratio = subject.totalLessons > 0
        ? subject.lessonsCompleted / subject.totalLessons
        : 0.0;

    // Stagger animation using an interval
    final delayedAnim = CurvedAnimation(
      parent: animation,
      curve: Interval(delay.clamp(0.0, 0.8), 1.0, curve: Curves.easeOutCubic),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: bgColor.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Row(
        children: [
          // Subject icon
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(subject.emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        subject.subjectName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${subject.lessonsCompleted}/${subject.totalLessons} درس',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: bgColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: delayedAnim,
                  builder: (ctx, snap) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: ratio * delayedAnim.value,
                      minHeight: 12,
                      backgroundColor: bgColor.withValues(alpha: 0.14),
                      valueColor: AlwaysStoppedAnimation(bgColor),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '🎯 إتقان: ${subject.averageMastery.round()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    AnimatedBuilder(
                      animation: delayedAnim,
                      builder: (ctx, snap) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: bgColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(ratio * delayedAnim.value * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: bgColor,
                          ),
                        ),
                      ),
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

// ─────────────────────────────────────────────────────────────
// 5. Achievements card
// ─────────────────────────────────────────────────────────────
class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard({required this.child, required this.detail});
  final ChildSummaryModel child;
  final ChildDetailModel detail;

  List<_BadgeData> get _badges {
    final badges = <_BadgeData>[];
    if (detail.lessonsCompleted >= 1) {
      badges.add(const _BadgeData('🌟', 'متعلم نشيط'));
    }
    if (detail.lessonsCompleted >= 5) {
      badges.add(const _BadgeData('📚', 'قارئ ماهر'));
    }
    if (detail.currentStreak >= 3) {
      badges.add(const _BadgeData('🔥', 'مثابر'));
    }
    if (detail.overallMastery >= 70) {
      badges.add(const _BadgeData('🏅', 'متميز'));
    }
    if (detail.totalQuizzesTaken >= 5) {
      badges.add(const _BadgeData('🎯', 'محترف'));
    }
    return badges;
  }

  @override
  Widget build(BuildContext context) {
    final badges = _badges;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC81E), Color(0xFFFFD96A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.42),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🏆', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text(
                'الإنجازات',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6B4200),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _AchievItem(
                emoji: '⭐',
                value: '${detail.totalPoints}',
                label: 'نجمة',
              ),
              _AchievItem(
                emoji: '✅',
                value: '${detail.lessonsCompleted}',
                label: 'درس',
              ),
              _AchievItem(
                emoji: '🔥',
                value: '${detail.currentStreak}',
                label: 'يوم',
              ),
              _AchievItem(
                emoji: '🎯',
                value: '${detail.overallMastery.round()}%',
                label: 'إتقان',
              ),
            ],
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: const Color(0x336B4200)),
            const SizedBox(height: 12),
            const Text(
              'الشارات المكتسبة 🎖',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6B4200),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badges
                  .map(
                    (b) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(b.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 5),
                          Text(
                            b.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6B4200),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _AchievItem extends StatelessWidget {
  const _AchievItem({
    required this.emoji,
    required this.value,
    required this.label,
  });
  final String emoji, value, label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: Colors.white38,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 26)),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF6B4200),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9A6A10),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.emoji, required this.label});
  final String emoji, label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });
  final String emoji, label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularPercent extends StatelessWidget {
  const _CircularPercent({
    required this.value,
    required this.color,
    required this.size,
  });
  final double value;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 8,
              backgroundColor: const Color(0xFFF0EDE0),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: size * 0.21,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// States: loading / error / empty
// ─────────────────────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
            strokeWidth: 4,
          ),
          SizedBox(height: 20),
          Text(
            'جارٍ تحميل بيانات طفلك...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😕', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'تعذّر تحميل البيانات',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('👶', style: TextStyle(fontSize: 72)),
            SizedBox(height: 16),
            Text(
              'لا يوجد أطفال بعد',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'أضف طفلك من شاشة الملفات الشخصية\nليبدأ رحلة التعلم! 🚀',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Internal data holder
// ─────────────────────────────────────────────────────────────
class _BadgeData {
  const _BadgeData(this.emoji, this.label);
  final String emoji;
  final String label;
}
