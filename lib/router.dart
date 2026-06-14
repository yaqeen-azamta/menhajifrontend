import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/student_register_screen.dart';
import 'screens/parent_register_screen.dart';
import 'screens/teacher_register_screen.dart';
import 'screens/teacher_dashboard_screen.dart';
import 'screens/profiles_screen.dart';
import 'screens/change_avatar_screen.dart';
import 'screens/change_grade_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/reading_screen.dart';
import 'screens/path_screen.dart';
import 'screens/lesson_screen.dart';
import 'screens/question_screen.dart';
import 'screens/quiz_screen.dart' as quiz;
import 'screens/adaptive_quiz_result_screen.dart';
import 'screens/rewards_screen.dart';
import 'models/adaptive_quiz_models.dart';
import 'tracing/screens/tracing_list_screen.dart';
import 'tracing/screens/tracing_exercise_screen.dart';

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (ctx, st) => const SplashScreen()),

      GoRoute(path: '/login', builder: (ctx, st) => const LoginScreen()),

      // ── Registration flow ──────────────────────────────────────
      GoRoute(
        path: '/role-select',
        builder: (ctx, st) => const RoleSelectionScreen(),
      ),

      GoRoute(
        path: '/register/student',
        builder: (ctx, st) => const StudentRegisterScreen(),
      ),

      GoRoute(
        path: '/register/parent',
        builder: (ctx, st) => const ParentRegisterScreen(),
      ),

      GoRoute(
        path: '/register/teacher',
        builder: (ctx, st) => const TeacherRegisterScreen(),
      ),

      // ── Teacher ────────────────────────────────────────────────
      GoRoute(
        path: '/teacher',
        builder: (ctx, st) => const TeacherDashboardScreen(),
      ),

      // ── Parent ─────────────────────────────────────────────────
      GoRoute(path: '/profiles', builder: (ctx, st) => const ProfilesScreen()),

      // ── Student ────────────────────────────────────────────────
      GoRoute(
        path: '/home',
        builder: (ctx, st) => const MainNavigationScreen(),
      ),

      GoRoute(
        path: '/path',
        builder: (_, state) => PathScreen(
          subject: state.uri.queryParameters['subject'],
          subjectId: state.uri.queryParameters['subjectId'],
        ),
      ),

      GoRoute(
        path: '/lesson/:id',
        builder: (_, state) =>
            LessonScreen(lessonId: state.pathParameters['id']!),
      ),

      GoRoute(
        path: '/questions/:id',
        builder: (_, state) =>
            QuestionScreen(lessonId: state.pathParameters['id']!),
      ),

      GoRoute(
        path: '/quiz/:id',
        builder: (_, state) =>
            quiz.QuizScreen(lessonId: state.pathParameters['id']!),
      ),

      GoRoute(
        path: '/rewards',
        builder: (_, state) {
          final p = state.uri.queryParameters;
          return RewardsScreen(
            stars: int.tryParse(p['stars'] ?? '') ?? 0,
            xp: int.tryParse(p['xp'] ?? '') ?? 0,
            correct: int.tryParse(p['correct'] ?? '') ?? 0,
            total: int.tryParse(p['total'] ?? '') ?? 0,
            lessonId: p['lesson_id'],
          );
        },
      ),

      // ── Settings sub-screens ───────────────────────────────────
      GoRoute(
        path: '/change-avatar',
        builder: (_, _) => const ChangeAvatarScreen(),
      ),
      GoRoute(
        path: '/change-grade',
        builder: (_, _) => const ChangeGradeScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (_, _) => const ChangePasswordScreen(),
      ),

      // ── Reading Assessment ─────────────────────────────────────
      // `extra` carries the reading text forwarded by QuestionScreen so that
      // ReadingScreen can skip the GET /api/reading/lesson/{id} call and use
      // the question's own text directly.
      GoRoute(
        path: '/reading/:lessonId',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;

          return ReadingScreen(
            lessonId: state.pathParameters['lessonId']!,
            readingText: extra['text'] as String?,
            questionId: extra['questionId'] as int,
            onComplete: extra['onComplete'] as void Function()?,
          );
        },
      ),
      // ── Adaptive quiz result ────────────────────────────────────
      GoRoute(
        path: '/adaptive-quiz-result',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return AdaptiveQuizResultScreen(
            result: extra['result'] as AdaptiveQuizResult,
            difficulty: extra['difficulty'] as int? ?? 1,
            focusSkills: (extra['focusSkills'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const [],
            lessonId: extra['lessonId'] as String? ?? '',
          );
        },
      ),

      // ── Tracing ────────────────────────────────────────────────
      GoRoute(
        path: '/tracing',
        builder: (_, state) => TracingListScreen(
          studentId: state.uri.queryParameters['studentId'] ?? 'guest',
        ),
      ),

      GoRoute(
        path: '/tracing/:questionId',
        builder: (_, state) {
          final qId = state.pathParameters['questionId']!;
          final studentId = state.uri.queryParameters['studentId'] ?? 'guest';
          final text = state.uri.queryParameters['text'] ?? '';

          return TracingExerciseScreen(
            questionId: qId,
            studentId: studentId,
            text: text,
          );
        },
      ),
    ],
  );
}
