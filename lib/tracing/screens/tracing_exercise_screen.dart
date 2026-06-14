import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/theme.dart';
import '../models/tracing_result.dart';
import '../models/tracing_submission.dart';
import '../services/tracing_api_service.dart';
import '../utils/tracing_helper.dart';

/// Full-screen tracing exercise.
///
/// Accepts [questionId], [studentId], and [text] (the character / word /
/// shape keyword to trace).  When the game engine reports completion it
/// submits a result to the backend via [TracingApiService] and shows a
/// completion dialog.
class TracingExerciseScreen extends StatefulWidget {
  final String questionId;
  final String studentId;
  final String text;

  const TracingExerciseScreen({
    super.key,
    required this.questionId,
    required this.studentId,
    required this.text,
  });

  @override
  State<TracingExerciseScreen> createState() => _TracingExerciseScreenState();
}

class _TracingExerciseScreenState extends State<TracingExerciseScreen> {
  bool _completed = false;
  late DateTime _startTime;
  int _gameKey = 0; // incremented on retry to force widget re-creation

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  // ── Game callback ────────────────────────────────────────────────────────

  Future<void> _onGameFinished(int index) async {
    if (_completed) return;
    _completed = true;

    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;

    final result = TracingResult(
      accuracy: 1.0,
      coverage: 1.0,
      precision: 1.0,
      isCorrect: true,
      score: 100,
      questionId: widget.questionId,
      timeSpentMs: elapsed,
    );

    try {
      await TracingApiService.instance.submitTracing(
        TracingSubmission(
          studentId: widget.studentId,
          questionId: widget.questionId,
          strokes: const [],
          result: result,
        ),
      );
    } catch (e) {
      debugPrint('Tracing submit error: $e');
    }

    if (!mounted) return;
    _showCompletionDialog();
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  void _showCompletionDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '🌟 أحسنت!',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
        ),
        content: const Text(
          'لقد أتممت التتبع بنجاح.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          // Retry — rebuild the game widget from scratch
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _completed = false;
                _startTime = DateTime.now();
                _gameKey++;
              });
            },
            child: Text(
              AppStrings.tracingClear,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // Done — pop screen
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text(
              'تم',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.text,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: KeyedSubtree(
              key: ValueKey('exercise_${widget.questionId}_$_gameKey'),
              child: TracingHelper.buildGameWidget(
                text: widget.text,
                onGameFinished: _onGameFinished,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
