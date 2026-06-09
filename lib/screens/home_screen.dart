import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/avatar_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/lesson_service.dart';
import '../services/parent_progress_service.dart';
import '../theme/theme.dart';
import '../widgets/fat_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ChildDetailModel? _child;
  LessonSummaryModel? _nextLesson;
  bool _loading = true;
  String? _error;

  int? _studentId;
  String? _studentName;
  String? _studentAvatar;
  // true when the student logged in directly (not via parent selecting a child)
  bool _isDirectStudent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Determine role FIRST so every redirect below uses the correct target.
      final role = await AuthService.instance.getCurrentRole();
      final isDirectStudent = role == 'STUDENT';
      _isDirectStudent = isDirectStudent;

      _studentId = prefs.getInt('active_student_id');
      _studentName = prefs.getString('active_student_name') ?? 'Student';
      _studentAvatar = prefs.getString('active_student_avatar');

      debugPrint('HomeScreen: role=$role  studentId=$_studentId');

      // ── Guard: no active student selected ─────────────────
      if (_studentId == null) {
        if (mounted) {
          // Direct student: token is valid but session wasn't activated —
          // send to login rather than the parent profiles screen.
          context.go(isDirectStudent ? '/login' : '/profiles');
        }
        return;
      }

      // ── Guard: studentId must NOT equal parentId ───────────
      // Only relevant for parent-managed sessions; skip for direct students.
      if (!isDirectStudent) {
        final parentId = await AuthService.instance.getParentId();
        debugPrint('HomeScreen: parentId=$parentId');

        if (_studentId == parentId) {
          debugPrint('ERROR: active_student_id == parentId — redirecting');
          await prefs.remove('active_student_id');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(AppStrings.homeSelectChild),
                backgroundColor: Colors.orange,
              ),
            );
            context.go('/profiles');
          }
          return;
        }
      }

      debugPrint('Token active for student $_studentId');

      // ── Load student summary ───────────────────────────────
      final summary = await ProgressService.instance.getSummary(_studentId!);

      // ── Load subjects for current grade ────────────────────
      final grade = prefs.getInt('active_grade_level') ?? 1;
      debugPrint(
        'HomeScreen: loading subjects grade=$grade studentId=$_studentId',
      );
      final subjects = await LessonService.instance.getSubjects(
        grade,
        studentId: _studentId,
      );
      debugPrint('========== SUBJECTS ==========');

      for (final s in subjects) {
        debugPrint(
          'SUBJECT=${s.name} completed=${s.completedLessons} total=${s.totalLessons}',
        );
      }

      debugPrint('==============================');

      // ── Build lightweight child object ─────────────────────
      final child = ChildDetailModel(
        studentId: _studentId!,
        fullName: _studentName ?? 'Student',
        gradeLevel: grade,
        totalPoints: summary.totalPoints,
        currentStreak: summary.currentStreak,
        lessonsCompleted: summary.completedLessons,
        lessonsInProgress: 0,
        totalLessons: summary.totalLessons,
        totalQuizzesTaken: summary.totalQuizzesTaken,
        averageQuizScore: summary.averageQuizScore,
        overallMastery: summary.overallMastery,
        subjectBreakdown: subjects
            .map(
              (s) => SubjectMasteryModel(
                subjectId: s.id,
                subjectName: s.name,
                totalLessons: s.totalLessons,
                lessonsCompleted: s.completedLessons,
                averageMastery: 0,
                coverImage: s.coverImage,
              ),
            )
            .toList(),
      );

      // ── Find first incomplete lesson ───────────────────────
      LessonSummaryModel? nextLesson;
      for (final s in subjects) {
        if (s.completedLessons < s.totalLessons) {
          final lessons = await LessonService.instance.getLessonsBySubject(
            s.id,
            studentId: _studentId,
          );
          for (final l in lessons) {
            if (!l.isCompleted) {
              nextLesson = l;
              break;
            }
          }
          if (nextLesson != null) break;
        }
      }

      setState(() {
        _child = child;
        _nextLesson = nextLesson;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        debugPrint('HomeScreen: auth error ${e.statusCode} — clearing session');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('active_student_id');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.homeSessionExpired),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );

          if (_isDirectStudent) {
            // Direct student: clear everything and return to login.
            await AuthService.instance.logout();
            context.go('/login');
          } else {
            // Parent-managed session: restore parent JWT and go back to
            // child selection — do NOT call any parent-only APIs here.
            await AuthService.instance.switchToParent();
            context.go('/profiles');
          }
        }
        return;
      }
      debugPrint('HomeScreen._load ApiException: $e');
      setState(() => _error = e.message);
    } catch (e) {
      debugPrint('HomeScreen._load error: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _switchProfile() async {
    // Capture router before any await so we don't use BuildContext across
    // async gaps (use_build_context_synchronously lint).
    final router = GoRouter.of(context);

    if (_isDirectStudent) {
      await AuthService.instance.logout();
      if (mounted) router.go('/login');
    } else {
      await AuthService.instance.switchToParent();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_student_id');
      if (mounted) router.go('/profiles');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _child == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('😕', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'حدث خطأ ما.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                FatButton(label: AppStrings.retry, onPressed: _load),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _switchProfile,
                  child: const Text(
                    AppStrings.homeSwitchProfile,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final child = _child!;
    final next = _nextLesson;
    final name = _studentName ?? child.fullName;
    final avatar = AvatarConfig.resolve(_studentAvatar).emoji;

    final totalLessons = child.subjectBreakdown.fold<int>(
      0,
      (s, x) => s + x.totalLessons,
    );
    final completedTotal = child.subjectBreakdown.fold<int>(
      0,
      (s, x) => s + x.lessonsCompleted,
    );
    final progressFraction = totalLessons == 0
        ? 0.0
        : (completedTotal / totalLessons).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── TOP BAR ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _switchProfile,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFE8DCC8),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                avatar,
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      _StatPill(icon: '🔥', value: '${child.currentStreak}'),
                      const SizedBox(width: 8),
                      _StatPill(icon: '⭐', value: '${child.totalPoints}'),
                    ],
                  ),
                ),

                // ── GREETING ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.homeGreeting(name),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        AppStrings.homeSubtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── DAILY GOAL (unified card with next lesson inside) ──
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFDDF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFFFC81E),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Text(
                            AppStrings.homeDailyGoal,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            totalLessons == 0
                                ? AppStrings.homeNoLessons
                                : AppStrings.homeLessonsProgress(
                                    completedTotal,
                                    totalLessons,
                                  ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.flame,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 14,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: LinearProgressIndicator(
                            value: progressFraction,
                            backgroundColor: Colors.white,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        totalLessons == 0
                            ? AppStrings.homeLessonsSoon
                            : progressFraction >= 1.0
                            ? AppStrings.homeAllDone
                            : AppStrings.homeKeepGoing,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (next != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: Color(0xFFE8DCC8)),
                        ),
                        const Text(
                          AppStrings.homeNextUp,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          next.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.homeNextMeta(
                            next.semesterNumber,
                            next.orderIndex,
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FatButton(
                          label: AppStrings.homeStartLesson(next.title),
                          onPressed: () async {
                            await context.push('/lesson/${next.id}');

                            // refresh after returning
                            await _load();
                          },
                        ),
                      ] else if (totalLessons == 0) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: Color(0xFFE8DCC8)),
                        ),
                        const Text(
                          AppStrings.homeWelcomeMsg,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── SUBJECTS ──────────────────────────────────
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    AppStrings.homeSubjects,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),

                if (child.subjectBreakdown.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      AppStrings.homeNoSubjects,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: child.subjectBreakdown.map((s) {
                        final w = (MediaQuery.of(context).size.width - 64) / 2;
                        return SizedBox(
                          width: w,
                          child: _SubjectCard(
                            subjectKey: s.key,
                            label: s.subjectName,
                            emoji: s.emoji,
                            total: s.totalLessons,
                            done: s.lessonsCompleted,
                            coverImage: s.coverImage,
                            onTap: () => context.push(
                              '/path?subject=${s.key}&subjectId=${s.subjectId}',
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.value});
  final String icon, value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subjectKey,
    required this.label,
    required this.emoji,
    required this.total,
    required this.done,
    required this.onTap,
    this.coverImage,
  });

  final String subjectKey, label, emoji;
  final int total, done;
  final String? coverImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, sh) = SubjectColors.of(subjectKey);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: coverImage != null && coverImage!.isNotEmpty
                  ? Image.network(
                      coverImage!.startsWith('http')
                          ? coverImage!
                          : 'http://192.168.0.192:8080$coverImage',
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                    )
                  : _placeholder(bg, sh),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              AppStrings.homeLessonsDone(done, total),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(Color bg, Color sh) {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: sh, width: 4)),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 32)),
    );
  }
}
