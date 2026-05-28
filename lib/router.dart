import 'package:flutter_application_1/tracing/models/tracing_question.dart';
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
import 'screens/home_screen.dart';
import 'screens/path_screen.dart';
import 'screens/lesson_screen.dart';
import 'screens/question_screen.dart';
import 'screens/quiz_screen.dart' as quiz;
import 'screens/rewards_screen.dart';
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
      GoRoute(path: '/home', builder: (ctx, st) => const HomeScreen()),

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
          final imageUrl = state.uri.queryParameters['image'] ?? '';
          final text = state.uri.queryParameters['text'] ?? '';

          return TracingExerciseScreen(
            question: TracingQuestion(
              id: qId,
              displayText: text,
              instruction: 'Trace carefully',
              category: TracingCategory.number,
              guideStrokes: const [],
              imageUrl: imageUrl,
            ),
            studentId: studentId,
            initialIndex: 0,
            allQuestions: const [],
          );
        },
      ),
    ],
  );
}
