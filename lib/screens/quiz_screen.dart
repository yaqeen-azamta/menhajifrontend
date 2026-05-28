// ════════════════════════════════════════════════════════════════════════════
// quiz_screen.dart — Quiz Orchestrator
// ════════════════════════════════════════════════════════════════════════════
//
// Responsibilities:
//   • Load quiz (parsed into QuizDocument, supports all 9 question types)
//   • Start a new attempt via QuizService.startAttempt
//   • Track current question index, hearts, correct count
//   • Render the current question via QuestionRenderer (type-agnostic)
//   • Receive SubmittedAnswer from any question widget
//   • Submit answer via QuizService.submitAnswer
//   • Move to next question or complete attempt → navigate to rewards
//
// This screen is type-agnostic — it never knows what kind of question it's
// showing. QuestionRenderer dispatches to the correct widget based on
// question.type.
//
// To customize behavior for a single question type, only the corresponding
// widget in widgets/quiz/questions/ needs to change.
//
// Backend endpoints used (all via QuizService + ApiClient):
//   GET  /api/quiz/lesson/{lessonId}
//   POST /api/quiz/attempt/start/{quizId}
//   POST /api/quiz/attempt/{attemptId}/answer
//   POST /api/quiz/attempt/{attemptId}/complete
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_strings.dart';
import '../models/question_model.dart';
import '../services/api_client.dart';
import '../services/quiz_service.dart';
import '../theme/theme.dart';
import '../widgets/fat_button.dart';
import '../widgets/quiz/question_callback.dart';
import '../widgets/quiz/question_renderer.dart';
import '../widgets/quiz/shared/feedback_panel.dart';
import '../widgets/quiz/shared/quiz_progress_bar.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.lessonId});
  final String lessonId;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // ── Loading / error ────────────────────────────────────────
  bool _loading = true;
  String? _error;

  // ── Quiz data ──────────────────────────────────────────────
  QuizDocument? _quiz;
  int? _attemptId;

  // ── Progress state ─────────────────────────────────────────
  int _idx = 0;
  int _hearts = 5;
  int _correctCount = 0;
  AnswerResult? _lastResult;
  bool _showFeedback = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Load quiz and start attempt ────────────────────────────
  //
  // We call ApiClient directly here (instead of QuizService.getQuizByLesson)
  // because QuizService returns a simplified QuizModel that only supports
  // MCQ-style options. Our QuizDocument supports all 9 question types
  // (tokens, wordBank, leftPairs/rightPairs, etc).
  //
  // We still use QuizService for everything else (startAttempt, submitAnswer,
  // completeAttempt) — those endpoints return data we model correctly already.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final lessonId = int.tryParse(widget.lessonId);
    if (lessonId == null) {
      setState(() {
        _error = 'Invalid lesson ID "${widget.lessonId}".';
        _loading = false;
      });
      return;
    }

    try {
      // 1. GET /api/quiz/lesson/{lessonId}
      final res = await ApiClient.instance.get('/api/quiz/lesson/$lessonId');
      final quiz = QuizDocument.fromJson(res['data'] as Map<String, dynamic>);

      if (quiz.questions.isEmpty) {
        setState(() {
          _error = 'No questions are available for this lesson yet.';
          _loading = false;
        });
        return;
      }

      // 2. POST /api/quiz/attempt/start/{quizId}
      final attempt = await QuizService.instance.startAttempt(quiz.id);

      setState(() {
        _quiz = quiz;
        _attemptId = attempt.attemptId;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not load quiz. ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Called by any question widget when student submits ─────
  Future<void> _onAnswer(SubmittedAnswer answer) async {
    if (_showFeedback || _attemptId == null) return;
    final q = _quiz!.questions[_idx];

    setState(() => _submitting = true);

    try {
      // POST /api/quiz/attempt/{attemptId}/answer
      final raw = await QuizService.instance.submitAnswer(
        attemptId: _attemptId!,
        questionId: q.id,
        answer: answer.answer,
        spokenText: answer.spokenText,
      );

      final answerResult = AnswerResult(
        isCorrect: raw.isCorrect,
        feedback: raw.feedback,
        correctAnswer: raw.correctAnswer,
        pointsEarned: raw.pointsEarned,
      );

      setState(() {
        _lastResult = answerResult;
        _showFeedback = true;
        if (raw.isCorrect) {
          _correctCount++;
        } else if (_hearts > 0) {
          _hearts--;
        }
      });
    } catch (e) {
      // Soft fail — show a backend-aware error in the feedback panel
      setState(() {
        _lastResult = AnswerResult(
          isCorrect: false,
          feedback: 'Could not check answer. ${e.toString()}',
          pointsEarned: 0,
        );
        _showFeedback = true;
        if (_hearts > 0) _hearts--;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Continue → next question or complete the attempt ──────
  Future<void> _continue() async {
    final quiz = _quiz!;
    final isLast = _idx >= quiz.questions.length - 1;

    if (!isLast) {
      setState(() {
        _idx++;
        _lastResult = null;
        _showFeedback = false;
      });
      return;
    }

    setState(() => _submitting = true);
    try {
      // POST /api/quiz/attempt/{attemptId}/complete
      final result = await QuizService.instance.completeAttempt(_attemptId!);

      final total = result.totalQuestions;
      final correct = result.correctAnswers;
      final stars = correct >= total
          ? 3
          : correct >= total - 1
          ? 2
          : 1;

      if (!mounted) return;
      _goToRewards(
        stars: stars,
        xp: result.pointsEarned,
        correct: correct,
        total: total,
      );
    } catch (_) {
      // Fall back to client-side scoring if the complete endpoint failed
      final total = quiz.questions.length;
      final stars = _correctCount >= total
          ? 3
          : _correctCount >= total - 1
          ? 2
          : 1;
      if (!mounted) return;
      _goToRewards(
        stars: stars,
        xp: _correctCount * 5 + 5,
        correct: _correctCount,
        total: total,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goToRewards({
    required int stars,
    required int xp,
    required int correct,
    required int total,
  }) {
    context.go(
      '/rewards'
      '?stars=$stars'
      '&xp=$xp'
      '&correct=$correct'
      '&total=$total'
      '&streak=0'
      '&new_badges=%5B%5D'
      '&lesson_id=${widget.lessonId}',
    );
  }

  bool get _isOutOfHearts => _hearts <= 0 && !_showFeedback;

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) return const _LoadingState();

    if (_error != null || _quiz == null || _quiz!.questions.isEmpty) {
      return _ErrorState(
        message: _error ?? AppStrings.quizNoQuestions,
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      );
    }

    if (_isOutOfHearts) {
      return _OutOfHeartsState(
        onRetry: () {
          setState(() {
            _hearts = 5;
            _idx = 0;
            _correctCount = 0;
            _lastResult = null;
            _showFeedback = false;
          });
          _load();
        },
      );
    }

    final quiz = _quiz!;
    final q = quiz.questions[_idx];
    final progress = (_idx + (_showFeedback ? 1 : 0)) / quiz.questions.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                QuizProgressBar(
                  progress: progress,
                  hearts: _hearts,
                  onClose: _showCloseDialog,
                ),
                Expanded(
                  child: QuestionRenderer(
                    question: q,
                    locked: _showFeedback || _submitting,
                    onAnswer: _onAnswer,
                  ),
                ),
              ],
            ),

            // Feedback panel (correct / wrong)
            if (_showFeedback && _lastResult != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: FeedbackPanel(
                  isCorrect: _lastResult!.isCorrect,
                  feedback: _lastResult!.feedback,
                  correctAnswer: _lastResult!.correctAnswer,
                  isLast: _idx >= quiz.questions.length - 1,
                  submitting: _submitting,
                  onContinue: _continue,
                ),
              ),

            // Submission overlay
            if (_submitting && !_showFeedback)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCloseDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          AppStrings.quizQuitTitle,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(AppStrings.quizQuitContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              AppStrings.quizKeepGoing,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              AppStrings.quizQuit,
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.canPop() ? context.pop() : context.go('/home');
    }
  }
}

// ─────────────────────────────────────────────────────────────
// State widgets — Loading / Error / Out of hearts
// ─────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              AppStrings.quizLoadingMsg,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onBack});
  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('😕', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              FatButton(label: AppStrings.goBack, onPressed: onBack),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutOfHeartsState extends StatelessWidget {
  const _OutOfHeartsState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💔', style: TextStyle(fontSize: 80)),
              const SizedBox(height: 16),
              const Text(
                AppStrings.quizOutOfHearts,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                AppStrings.quizOutOfHeartsMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              FatButton(
                label: AppStrings.quizTryAgain,
                color: FatColor.danger,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
