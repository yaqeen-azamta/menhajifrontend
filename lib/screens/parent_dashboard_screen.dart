import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/parent_progress_service.dart';
import '../models/avatar_config.dart';

// ─── Professional parent-portal palette ───────────────────────
const _kPrimary = Color(0xFF1E3A5F);
const _kSecondary = Color(0xFF2563EB);
const _kSuccess = Color(0xFF10B981);
const _kWarning = Color(0xFFF59E0B);
const _kDanger = Color(0xFFEF4444);
const _kPurple = Color(0xFF7C3AED);
const _kBg = Color(0xFFF8FAFC);
const _kCard = Color(0xFFFFFFFF);
const _kText = Color(0xFF0F172A);
const _kTextSub = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);

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
      duration: const Duration(milliseconds: 900),
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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await AuthService.instance.switchToParent();
      final child = widget.dashboard.children[_selectedIndex];
      final detail = await ParentService.instance.getChildDetail(child.studentId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _loading = false;
        });
        _animCtrl.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
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

  ChildSummaryModel get _currentChild => widget.dashboard.children[_selectedIndex];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Column(
          children: [
            _ProfessionalHeader(
              onBack: () => Navigator.pop(context),
              onRefresh: _load,
            ),
            if (widget.dashboard.children.length > 1)
              _StudentSelector(
                children: widget.dashboard.children,
                selectedIndex: _selectedIndex,
                onSelect: _selectChild,
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
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
// Professional white header
// ─────────────────────────────────────────────────────────────
class _ProfessionalHeader extends StatelessWidget {
  const _ProfessionalHeader({required this.onBack, required this.onRefresh});
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          child: Row(
            children: [
              _HeaderIconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                color: _kPrimary,
                bgColor: const Color(0xFFF1F5F9),
                onTap: onBack,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'بوابة ولي الأمر',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _kText,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: _kTextSub,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'آخر تحديث: $time',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kTextSub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _HeaderIconBtn(
                icon: Icons.refresh_rounded,
                color: _kSecondary,
                bgColor: const Color(0xFFEFF6FF),
                onTap: onRefresh,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  const _HeaderIconBtn({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
  final IconData icon;
  final Color color, bgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 19),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Student selector chips (replaces orange tab bar)
// ─────────────────────────────────────────────────────────────
class _StudentSelector extends StatelessWidget {
  const _StudentSelector({
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
      color: _kCard,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 10),
          const Text(
            'اختر الطالب',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kTextSub,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(children.length, (i) {
                final c = children[i];
                final selected = i == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? _kPrimary : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? _kPrimary : _kBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 14,
                            color: selected ? Colors.white : _kTextSub,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            c.fullName.split(' ').first,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : _kText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
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
      color: _kSecondary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          _StudentProfileCard(child: child, detail: detail),
          const SizedBox(height: 14),
          _KpiGrid(detail: detail, animation: animation),
          const SizedBox(height: 14),
          _ProgressOverviewCard(detail: detail, animation: animation),
          const SizedBox(height: 14),
          _RecentActivityCard(detail: detail),
          if (detail.subjectBreakdown.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SubjectProgressSection(detail: detail, animation: animation),
          ],
          const SizedBox(height: 14),
          _MilestonesCard(detail: detail),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 1. Student profile card
// ─────────────────────────────────────────────────────────────
class _StudentProfileCard extends StatelessWidget {
  const _StudentProfileCard({required this.child, required this.detail});
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
    return _ProfCard(
      child: Row(
        children: [
          // Avatar with active indicator
          Stack(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _kSecondary.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  AvatarConfig.resolve(child.avatarId).emoji,
                  style: const TextStyle(fontSize: 34),
                ),
              ),
              Positioned(
                bottom: 2,
                left: 2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _kSuccess,
                    shape: BoxShape.circle,
                    border: Border.all(color: _kCard, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Name + tags
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.fullName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    _PillTag(
                      label: _gradeLabel,
                      color: _kPrimary,
                      bgColor: _kPrimary.withValues(alpha: 0.08),
                    ),
                    _PillTag(
                      label: 'نشط',
                      color: _kSuccess,
                      bgColor: _kSuccess.withValues(alpha: 0.10),
                      icon: Icons.circle,
                      iconSize: 6,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Mastery ring
          _SmallRing(
            value: detail.overallMastery / 100,
            color: _kSecondary,
            size: 56,
            label: 'إتقان',
          ),
        ],
      ),
    );
  }
}

class _PillTag extends StatelessWidget {
  const _PillTag({
    required this.label,
    required this.color,
    required this.bgColor,
    this.icon,
    this.iconSize = 11.0,
  });
  final String label;
  final Color color, bgColor;
  final IconData? icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 2. KPI grid — 4 analytics cards
// ─────────────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.detail, required this.animation});
  final ChildDetailModel detail;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (ctx, _) {
        final v = animation.value.clamp(0.0, 1.0);
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    icon: Icons.trending_up_rounded,
                    iconColor: _kSecondary,
                    iconBg: const Color(0xFFEFF6FF),
                    value: '${detail.overallMastery.round()}%',
                    label: 'مستوى الإتقان',
                    animValue: v,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.menu_book_rounded,
                    iconColor: _kSuccess,
                    iconBg: const Color(0xFFF0FDF4),
                    value: '${detail.lessonsCompleted}',
                    label: 'دروس مكتملة',
                    animValue: v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    icon: Icons.stars_rounded,
                    iconColor: _kWarning,
                    iconBg: const Color(0xFFFFFBEB),
                    value: '${detail.totalPoints}',
                    label: 'مجموع النقاط',
                    animValue: v,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: _kDanger,
                    iconBg: const Color(0xFFFFF1F1),
                    value: '${detail.currentStreak}',
                    label: 'أيام متواصلة',
                    animValue: v,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    required this.animValue,
  });
  final IconData icon;
  final Color iconColor, iconBg;
  final String value, label;
  final double animValue;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: animValue,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - animValue)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 12,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _kText,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: _kTextSub,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
// 3. Progress overview card
// ─────────────────────────────────────────────────────────────
class _ProgressOverviewCard extends StatelessWidget {
  const _ProgressOverviewCard({required this.detail, required this.animation});
  final ChildDetailModel detail;
  final Animation<double> animation;

  int get _total => detail.effectiveTotalLessons;
  int get _done => detail.lessonsCompleted;
  double get _ratio => _total > 0 ? _done / _total : 0.0;

  @override
  Widget build(BuildContext context) {
    return _ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.bar_chart_rounded,
            iconColor: _kSecondary,
            label: 'نظرة عامة على التقدم',
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: numbers + bar
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
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: _kPrimary,
                              height: 1,
                            ),
                          ),
                          TextSpan(
                            text: ' / $_total',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _kTextSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'درس مكتمل',
                      style: TextStyle(
                        fontSize: 12,
                        color: _kTextSub,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedBuilder(
                      animation: animation,
                      builder: (ctx, _) {
                        final v = _ratio * animation.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'الإنجاز الكلي',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _kTextSub,
                                  ),
                                ),
                                Text(
                                  '${(v * 100).round()}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _kPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: v,
                                minHeight: 8,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation(_kSecondary),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Right: circular ring
              AnimatedBuilder(
                animation: animation,
                builder: (ctx, _) => _CircularRing(
                  value: _ratio * animation.value,
                  color: _kPrimary,
                  size: 86,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 14),
          // Metrics row
          Row(
            children: [
              _InlineMetric(
                icon: Icons.auto_awesome_rounded,
                iconColor: _kSecondary,
                value: '${detail.overallMastery.round()}%',
                label: 'الإتقان',
              ),
              _VDivider(),
              _InlineMetric(
                icon: Icons.hourglass_top_rounded,
                iconColor: _kWarning,
                value: '${detail.lessonsInProgress}',
                label: 'جارٍ',
              ),
              if (detail.totalQuizzesTaken > 0) ...[
                _VDivider(),
                _InlineMetric(
                  icon: Icons.quiz_rounded,
                  iconColor: _kPurple,
                  value: '${detail.totalQuizzesTaken}',
                  label: 'اختبار',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final String value, label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: _kTextSub,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 38, color: _kBorder);
}

// ─────────────────────────────────────────────────────────────
// 4. Recent learning activity (timeline)
// ─────────────────────────────────────────────────────────────
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.detail});
  final ChildDetailModel detail;

  @override
  Widget build(BuildContext context) {
    final hasQuiz = detail.totalQuizzesTaken > 0;
    final hasProgress =
        detail.lessonsCompleted > 0 || detail.lessonsInProgress > 0;

    return _ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.timeline_rounded,
            iconColor: _kSuccess,
            label: 'نشاط التعلم الأخير',
          ),
          const SizedBox(height: 16),
          if (!hasProgress && !hasQuiz)
            _EmptyActivity()
          else
            _buildTimeline(hasQuiz),
        ],
      ),
    );
  }

  Widget _buildTimeline(bool hasQuiz) {
    final items = <_TimelineItem>[];

    if (detail.lessonsCompleted > 0) {
      items.add(_TimelineItem(
        icon: Icons.check_circle_rounded,
        iconColor: _kSuccess,
        title: 'الدروس المكتملة',
        subtitle:
            '${detail.lessonsCompleted} درس من أصل ${detail.effectiveTotalLessons}',
      ));
    }
    if (detail.lessonsInProgress > 0) {
      items.add(_TimelineItem(
        icon: Icons.play_circle_rounded,
        iconColor: _kSecondary,
        title: 'دروس جارٍ العمل عليها',
        subtitle: '${detail.lessonsInProgress} درس في التقدم',
      ));
    }
    if (hasQuiz) {
      items.add(_TimelineItem(
        icon: Icons.assignment_turned_in_rounded,
        iconColor: _kPurple,
        title: 'نتائج الاختبارات',
        subtitle:
            '${detail.averageQuizScore.toStringAsFixed(1)}% متوسط الدرجات (${detail.totalQuizzesTaken} اختبار)',
      ));
    }
    // Always add mastery row
    items.add(_TimelineItem(
      icon: Icons.auto_awesome_rounded,
      iconColor: _kWarning,
      title: 'مستوى الإتقان العام',
      subtitle: '${detail.overallMastery.toStringAsFixed(1)}%',
    ));

    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final isLast = i == items.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 36,
                child: Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: item.iconColor.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(item.icon, color: item.iconColor, size: 17),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          decoration: BoxDecoration(
                            color: _kBorder,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: isLast ? 0 : 14,
                    top: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kTextSub,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _TimelineItem {
  const _TimelineItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
}

class _EmptyActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline_rounded, color: _kTextSub, size: 17),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'لا يوجد نشاط بعد — شجّع طفلك على بدء أول درس',
              style: TextStyle(
                fontSize: 13,
                color: _kTextSub,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 5. Subject progress section
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
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _SectionHeader(
            icon: Icons.auto_stories_rounded,
            iconColor: _kPrimary,
            label: 'تقدم المواد الدراسية',
            standalone: true,
          ),
        ),
        ...detail.subjectBreakdown.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SubjectCard(
              subject: e.value,
              animation: animation,
              delay: e.key * 0.10,
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

  static Color _color(String key) {
    switch (key) {
      case 'math':
        return _kSecondary;
      case 'reading':
        return _kSuccess;
      case 'science':
        return _kWarning;
      default:
        return _kPurple;
    }
  }

  static IconData _icon(String key) {
    switch (key) {
      case 'math':
        return Icons.calculate_rounded;
      case 'reading':
        return Icons.auto_stories_rounded;
      case 'science':
        return Icons.science_rounded;
      default:
        return Icons.school_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(subject.key);
    final ratio = subject.totalLessons > 0
        ? subject.lessonsCompleted / subject.totalLessons
        : 0.0;

    final delayedAnim = CurvedAnimation(
      parent: animation,
      curve: Interval(
        delay.clamp(0.0, 0.8),
        1.0,
        curve: Curves.easeOutCubic,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Subject icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(_icon(subject.key), color: color, size: 22),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedBuilder(
                      animation: delayedAnim,
                      builder: (ctx, _) => Text(
                        '${(ratio * delayedAnim.value * 100).round()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: delayedAnim,
                  builder: (ctx, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: ratio * delayedAnim.value,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${subject.lessonsCompleted}/${subject.totalLessons} درس',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _kTextSub,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 11,
                          color: _kTextSub,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'إتقان: ${subject.averageMastery.round()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kTextSub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
// 6. Milestones & Achievements card
// ─────────────────────────────────────────────────────────────
class _MilestonesCard extends StatelessWidget {
  const _MilestonesCard({required this.detail});
  final ChildDetailModel detail;

  List<_MilestoneData> get _milestones {
    final list = <_MilestoneData>[];
    if (detail.lessonsCompleted >= 1) {
      list.add(const _MilestoneData(
        icon: Icons.emoji_events_rounded,
        color: _kWarning,
        label: 'متعلم نشيط',
        desc: 'أكمل أول درس',
      ));
    }
    if (detail.lessonsCompleted >= 5) {
      list.add(const _MilestoneData(
        icon: Icons.local_library_rounded,
        color: _kSecondary,
        label: 'قارئ ماهر',
        desc: 'أكمل 5 دروس',
      ));
    }
    if (detail.currentStreak >= 3) {
      list.add(const _MilestoneData(
        icon: Icons.local_fire_department_rounded,
        color: _kDanger,
        label: 'مثابر',
        desc: '3 أيام متواصلة',
      ));
    }
    if (detail.overallMastery >= 70) {
      list.add(const _MilestoneData(
        icon: Icons.military_tech_rounded,
        color: _kSuccess,
        label: 'متميز',
        desc: 'إتقان 70%+',
      ));
    }
    if (detail.totalQuizzesTaken >= 5) {
      list.add(const _MilestoneData(
        icon: Icons.workspace_premium_rounded,
        color: _kPurple,
        label: 'محترف',
        desc: 'أكمل 5 اختبارات',
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final milestones = _milestones;
    return _ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.workspace_premium_rounded,
            iconColor: _kWarning,
            label: 'الإنجازات والشارات',
          ),
          const SizedBox(height: 16),
          // Stats summary strip
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AchievStat(
                  icon: Icons.stars_rounded,
                  iconColor: _kWarning,
                  value: '${detail.totalPoints}',
                  label: 'نقطة',
                ),
                Container(width: 1, height: 34, color: _kBorder),
                _AchievStat(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: _kSuccess,
                  value: '${detail.lessonsCompleted}',
                  label: 'درس',
                ),
                Container(width: 1, height: 34, color: _kBorder),
                _AchievStat(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: _kDanger,
                  value: '${detail.currentStreak}',
                  label: 'يوم',
                ),
                Container(width: 1, height: 34, color: _kBorder),
                _AchievStat(
                  icon: Icons.trending_up_rounded,
                  iconColor: _kSecondary,
                  value: '${detail.overallMastery.round()}%',
                  label: 'إتقان',
                ),
              ],
            ),
          ),
          if (milestones.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'الشارات المكتسبة',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kTextSub,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: milestones.map((m) => _BadgeChip(data: m)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MilestoneData {
  const _MilestoneData({
    required this.icon,
    required this.color,
    required this.label,
    required this.desc,
  });
  final IconData icon;
  final Color color;
  final String label, desc;
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.data});
  final _MilestoneData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: data.color.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(data.icon, color: data.color, size: 14),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: data.color,
                ),
              ),
              Text(
                data.desc,
                style: const TextStyle(
                  fontSize: 10,
                  color: _kTextSub,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievStat extends StatelessWidget {
  const _AchievStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final String value, label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 19),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _kText,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: _kTextSub,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared professional primitives
// ─────────────────────────────────────────────────────────────
class _ProfCard extends StatelessWidget {
  const _ProfCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 14,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.standalone = false,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _kText,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );

    if (!standalone) return content;

    // Standalone: wrap in a card-like container for section headings
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: content,
    );
  }
}

class _CircularRing extends StatelessWidget {
  const _CircularRing({
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
              strokeWidth: 7,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: size * 0.18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                'مكتمل',
                style: TextStyle(
                  fontSize: size * 0.11,
                  fontWeight: FontWeight.w500,
                  color: _kTextSub,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallRing extends StatelessWidget {
  const _SmallRing({
    required this.value,
    required this.color,
    required this.size,
    required this.label,
  });
  final double value;
  final Color color;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  strokeWidth: 4.5,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  fontSize: size * 0.195,
                  fontWeight: FontWeight.w800,
                  color: _kText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: _kTextSub,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _kSecondary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(_kSecondary),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'جارٍ تحميل بيانات الطالب...',
            style: TextStyle(
              fontSize: 14,
              color: _kTextSub,
              fontWeight: FontWeight.w600,
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
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1F1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _kDanger,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'تعذّر تحميل البيانات',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _kText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: _kTextSub,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _kSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: _kSecondary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: _kSecondary,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'لا يوجد طلاب بعد',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _kText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'أضف طفلك من شاشة الملفات الشخصية\nليبدأ رحلة التعلم',
              style: TextStyle(
                fontSize: 14,
                color: _kTextSub,
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
