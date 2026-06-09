import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../services/lesson_service.dart';
import '../theme/theme.dart';

class PathScreen extends StatefulWidget {
  const PathScreen({super.key, this.subject, this.subjectId});
  final String? subject;
  final String? subjectId; // numeric id passed from home screen subject card

  @override
  State<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends State<PathScreen> {
  List<LessonSummaryModel> _lessons = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final subjectId = int.tryParse(widget.subjectId ?? '');

      if (subjectId == null) {
        throw Exception('Missing subjectId');
      }

      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getInt('active_student_id');
      debugPrint('PathScreen: loading lessons subjectId=$subjectId studentId=$studentId');

      final lessons = await LessonService.instance.getLessonsBySubject(
        subjectId,
        studentId: studentId,
      );

      debugPrint('LESSONS LOADED = ${lessons.length}');

      setState(() {
        _lessons = lessons;
      });
    } catch (e) {
      debugPrint('PathScreen error = $e');

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.subject == null
        ? AppStrings.pathTitle
        : widget.subject == 'math'
        ? AppStrings.pathMath
        : widget.subject == 'reading'
        ? AppStrings.pathReading
        : AppStrings.pathScience;

    return Scaffold(
      backgroundColor: AppColors.pathBg,
      body: SafeArea(
        child: Column(
          children: [
            // TOP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    icon: const Icon(Icons.chevron_left, size: 28),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loadLessons,
                        child: const Text(AppStrings.retry),
                      ),
                    ],
                  ),
                ),
              )
            else if (_lessons.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    AppStrings.pathNoLessons,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  itemCount: _lessons.length,
                  itemBuilder: (ctx, idx) {
                    final l = _lessons[idx];
                    final isDone = l.isCompleted;
                    final firstUnfinished = _lessons.indexWhere(
                      (x) => !x.isCompleted,
                    );
                    final isCurrent = idx == firstUnfinished;
                    final isLocked = !isDone && !isCurrent;

                    final offsets = [0.0, 70.0, 100.0, 70.0];
                    final offset = offsets[idx % 4];

                    return Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: offset,
                        bottom: 16,
                      ),
                      child: _Node(
                        title: l.title,
                        done: isDone,
                        current: isCurrent,
                        locked: isLocked,
                        // l.id is a real numeric backend ID — safe to use
                        onTap: isLocked
                            ? null
                            : () => context.push('/lesson/${l.id}'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

}

// ── Node widget ───────────────────────────────────────────────
class _Node extends StatelessWidget {
  const _Node({
    required this.title,
    required this.done,
    required this.current,
    required this.locked,
    this.onTap,
  });

  final String title;
  final bool done, current, locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color nodeBg;
    Color nodeShadow;
    String icon;

    if (done) {
      nodeBg = AppColors.primary;
      nodeShadow = AppColors.primaryShadow;
      icon = '⭐';
    } else if (current) {
      nodeBg = AppColors.primary;
      nodeShadow = AppColors.primaryShadow;
      icon = '👑';
    } else {
      nodeBg = AppColors.lockBg;
      nodeShadow = AppColors.lockBorder;
      icon = '🔒';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: nodeBg,
              shape: BoxShape.circle,
              border: Border.all(color: nodeShadow, width: 3),
              boxShadow: [
                BoxShadow(
                  color: nodeShadow,
                  offset: const Offset(0, 6),
                  blurRadius: 0,
                  spreadRadius: -2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              icon,
              style: TextStyle(
                fontSize: 36,
                color: locked ? Colors.black26 : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: locked
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                done
                    ? AppStrings.pathCompleted
                    : current
                    ? AppStrings.pathTapToStart
                    : AppStrings.pathLocked,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
