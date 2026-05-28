import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/theme.dart';
import '../models/tracing_question.dart';
import '../models/tracing_result.dart';
import '../models/tracing_submission.dart';
import '../services/tracing_api_service.dart';
import '../widgets/result_dialog.dart';
import '../widgets/tracing_canvas_widget.dart';

class TracingExerciseScreen extends StatefulWidget {
  final TracingQuestion question;

  final String studentId;

  final int initialIndex;

  final List<TracingQuestion> allQuestions;

  const TracingExerciseScreen({
    super.key,
    required this.question,
    required this.studentId,
    this.initialIndex = 0,
    this.allQuestions = const [],
  });

  @override
  State<TracingExerciseScreen> createState() => _TracingExerciseScreenState();
}

class _TracingExerciseScreenState extends State<TracingExerciseScreen> {
  late TracingQuestion _q;

  final _canvasKey = GlobalKey<TracingCanvasState>();

  late DateTime _startTime;

  @override
  void initState() {
    super.initState();

    _q = widget.question;

    _startTime = DateTime.now();
  }

  // ───────────────── CHECK ─────────────────

  void _onCheck() {
    final state = _canvasKey.currentState;

    if (state == null) return;

    // Nothing drawn
    if (state.validStrokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.tracingDrawFirst),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    final elapsed = DateTime.now().difference(_startTime).inMilliseconds;

    // Simple success result
    final result = TracingResult(
      accuracy: 1.0,

      coverage: 1.0,

      precision: 1.0,

      isCorrect: true,

      score: 100,

      questionId: _q.id,

      timeSpentMs: elapsed,
    );

    // Save strokes
    final captured = state.tracingStrokes.map((s) => List.of(s)).toList();

    _submit(
      TracingSubmission(
        studentId: widget.studentId,

        questionId: _q.id,

        strokes: captured,

        result: result,
      ),
    );

    // Result dialog
    showDialog<void>(
      context: context,

      barrierDismissible: false,

      builder: (_) => ResultDialog(
        result: result,

        onRetry: () {
          Navigator.of(context).pop();

          state.clear();

          setState(() {
            _startTime = DateTime.now();
          });
        },

        onNext: () {
          Navigator.of(context).pop();

          _goNext();
        },
      ),
    );
  }

  // ───────────────── SUBMIT ───────────────

  Future<void> _submit(TracingSubmission submission) async {
    try {
      await TracingApiService.instance.submitTracing(submission);
    } catch (e) {
      debugPrint('Tracing submit error: $e');
    }
  }

  // ───────────────── NEXT ─────────────────

  void _goNext() {
    Navigator.of(context).pop();
  }

  // ───────────────── BUILD ────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,

      appBar: _buildAppBar(),

      body: SafeArea(
        child: Column(
          children: [
            // _buildHeader() removed: the guide image inside the canvas
            // already shows the character to trace — displaying it again
            // as large text above the canvas caused a visible duplication.

            Expanded(child: _buildCanvas()),

            _buildControls(),
          ],
        ),
      ),
    );
  }

  // ───────────────── APP BAR ──────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,

      foregroundColor: Colors.white,

      elevation: 0,

      title: Text(
        _q.instruction,

        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),

      centerTitle: true,
    );
  }


  // ───────────────── CANVAS ───────────────

  Widget _buildCanvas() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),

      child: Card(
        elevation: 6,

        shadowColor: Colors.black26,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

        clipBehavior: Clip.antiAlias,

        child: TracingCanvasWidget(key: _canvasKey, question: _q),
      ),
    );
  }

  // ───────────────── CONTROLS ─────────────

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),

      child: Row(
        children: [
          // Clear button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                _canvasKey.currentState?.clear();

                setState(() {
                  _startTime = DateTime.now();
                });
              },

              icon: const Icon(Icons.refresh_rounded),

              label: const Text(AppStrings.tracingClear),

              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),

                foregroundColor: AppColors.danger,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),

                padding: const EdgeInsets.symmetric(vertical: 14),

                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Check button
          Expanded(
            flex: 2,

            child: ElevatedButton.icon(
              onPressed: _onCheck,

              icon: const Icon(Icons.check_circle_rounded),

              label: const Text(AppStrings.tracingCheck),

              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,

                foregroundColor: Colors.white,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),

                padding: const EdgeInsets.symmetric(vertical: 14),

                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
