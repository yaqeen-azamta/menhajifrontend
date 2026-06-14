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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Single source of truth for learning data — used in both student and
  // parent modes. getStudentDashboard() passes ?studentId= when parent JWT.
  StudentDashboardModel? _dashboard;
  bool _loading = true;
  String? _error;

  int? _studentId;
  String? _studentName;
  String? _studentAvatar;
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

      final role = await AuthService.instance.getCurrentRole();
      final isDirectStudent = role == 'STUDENT';
      _isDirectStudent = isDirectStudent;

      _studentId = prefs.getInt('active_student_id');
      _studentName = prefs.getString('active_student_name') ?? 'Student';
      _studentAvatar = prefs.getString('active_student_avatar');

      debugPrint('HomeScreen: role=$role  studentId=$_studentId');
      print(
        'Current child session: role=$role studentId=$_studentId '
        'name=$_studentName',
      );

      if (_studentId == null) {
        if (mounted) context.go(isDirectStudent ? '/login' : '/profiles');
        return;
      }

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

      // Single call — works for both modes:
      // • Student JWT + no studentId param  → backend uses JWT identity
      // • Parent JWT + studentId param      → backend resolveStudentId() uses it
      final dashboard = await ProgressService.instance.getStudentDashboard(
        studentId: isDirectStudent ? null : _studentId,
      );

      setState(() => _dashboard = dashboard);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        debugPrint('HomeScreen: auth error ${e.statusCode} — ${e.message}');
        print('Session validation result: FAILED statusCode=${e.statusCode}');

        // In parent mode, the stale-token issue (switchToParent restoring an
        // expired token that _withRefresh had already rotated) can cause this
        // 401 spuriously.  Refresh the parent session once and retry before
        // surfacing the error to the user.
        if (!_isDirectStudent && _studentId != null) {
          try {
            debugPrint('HomeScreen: retrying after switchToParent refresh');
            await AuthService.instance.switchToParent();
            final dashboard = await ProgressService.instance.getStudentDashboard(
              studentId: _studentId,
            );
            if (mounted) {
              setState(() {
                _dashboard = dashboard;
                _loading = false;
              });
            }
            return;
          } catch (retryErr) {
            debugPrint('HomeScreen: retry also failed: $retryErr');
          }
        }

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
            await AuthService.instance.logout();
            context.go('/login');
          } else {
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

  static String _subjectKey(String name) {
    final n = name.toLowerCase();
    if (n.contains('math') || n.contains('رياض')) return 'math';
    if (n.contains('read') ||
        n.contains('arabic') ||
        n.contains('english') ||
        n.contains('عرب')) {
      return 'reading';
    }
    return 'science';
  }

  static String _subjectEmoji(String key) {
    switch (key) {
      case 'reading':
        return '📖';
      case 'science':
        return '🔬';
      default:
        return '🔢';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _dashboard == null) {
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

    final dashboard = _dashboard!;
    final name = _studentName ?? dashboard.fullName;
    final avatar = AvatarConfig.resolve(_studentAvatar ?? dashboard.avatarId).emoji;

    final completedLessons =
        dashboard.subjects.fold(0, (s, e) => s + e.completedLessons);
    final dailyGoal = dashboard.dailyGoal;
    final progressFraction = dailyGoal == 0
        ? 0.0
        : (completedLessons / dailyGoal).clamp(0.0, 1.0);
    final recommended = dashboard.recommendedLesson;

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
                              Text(avatar, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 6),
                              Text(
                                name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900),
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
                      _StatPill(
                          icon: '🔥', value: '${dashboard.currentStreak}'),
                      const SizedBox(width: 8),
                      _StatPill(icon: '⭐', value: '${dashboard.totalPoints}'),
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

                // ── PROGRESS CARD ─────────────────────────────
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
                            dailyGoal == 0
                                ? AppStrings.homeNoLessons
                                : AppStrings.homeLessonsProgress(
                                    completedLessons,
                                    dailyGoal,
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
                        dailyGoal == 0
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
                      if (recommended != null) ...[
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
                          recommended.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          recommended.subjectName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FatButton(
                          label: AppStrings.homeStart,
                          onPressed: () async {
                            await context.push(
                                '/lesson/${recommended.lessonId}');
                            await _load();
                          },
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

                if (dashboard.subjects.isEmpty)
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
                      children: dashboard.subjects.map((s) {
                        final key = _subjectKey(s.name);
                        final w =
                            (MediaQuery.of(context).size.width - 64) / 2;
                        return SizedBox(
                          width: w,
                          child: _SubjectCard(
                            subjectKey: key,
                            label: s.name,
                            emoji: _subjectEmoji(key),
                            total: s.totalLessons,
                            done: s.completedLessons,
                            coverImage: s.coverImage,
                            onTap: () => context.push(
                              '/path?subject=$key&subjectId=${s.id}',
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
                          : 'http://10.0.2.2:8080$coverImage',
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
