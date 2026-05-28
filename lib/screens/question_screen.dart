// ════════════════════════════════════════════════════════════════════════════
// QUESTION SCREEN
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_strings.dart';
import '../services/api_client.dart';
import '../services/lesson_service.dart';
import '../services/question_service.dart';
import '../theme/theme.dart';
import '../tracing/models/tracing_question.dart';
import '../tracing/widgets/tracing_canvas_widget.dart';
import '../widgets/fat_button.dart';

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  List<QuestionModel> _questions = [];

  bool _loading = true;

  String? _error;

  int _index = 0;

  String? _selectedAnswer;

  final TextEditingController _writeController = TextEditingController();

  // Key used to access the inline tracing canvas state (clear / read strokes).
  final _tracingCanvasKey = GlobalKey<TracingCanvasState>();

  @override
  void initState() {
    super.initState();

    _loadQuestions();
  }

  @override
  void dispose() {
    _writeController.dispose();

    super.dispose();
  }

  // ═════════ LOAD QUESTIONS ═════════

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;

      _error = null;
    });

    final id = int.tryParse(widget.lessonId);

    if (id == null) {
      setState(() {
        _error = 'Invalid lesson ID';

        _loading = false;
      });

      return;
    }

    try {
      final questions = await QuestionService.instance.getQuestionsByLesson(id);

      setState(() {
        _questions = questions;
      });
    } catch (e) {
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


  Future<void> _completeAndShowQuizDialog() async {
    final lessonId = int.tryParse(widget.lessonId);
    if (lessonId != null) {
      try {
        await LessonService.instance.completeLesson(lessonId);
      } catch (_) {
        // Non-fatal — still show the quiz dialog
      }
    }
    await _showQuizDialog();
  }

  Future<void> _showQuizDialog() async {
    if (!mounted) return;

    final takeQuiz = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          AppStrings.quizDialogTitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          AppStrings.quizDialogContent,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              AppStrings.quizDialogNo,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              AppStrings.quizDialogYes,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (takeQuiz == true) {
      context.go('/quiz/${widget.lessonId}');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ═════════ LOADING ═════════

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ═════════ ERROR ═════════

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,

        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                const Text('😕', style: TextStyle(fontSize: 50)),

                const SizedBox(height: 16),

                Text(
                  _error!,

                  textAlign: TextAlign.center,

                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 24),

                FatButton(label: AppStrings.retry, onPressed: _loadQuestions),
              ],
            ),
          ),
        ),
      );
    }

    // ═════════ EMPTY ═════════

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,

        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                const Text('📭', style: TextStyle(fontSize: 50)),

                const SizedBox(height: 16),

                const Text(
                  AppStrings.questionNoQuestions,

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 24),

                FatButton(label: AppStrings.goBack, onPressed: () => context.pop()),
              ],
            ),
          ),
        ),
      );
    }

    // ═════════ CURRENT QUESTION ═════════

    final q = _questions[_index];

    final progress = (_index + 1) / _questions.length;

    return Scaffold(
      backgroundColor: AppColors.bg,

      body: SafeArea(
        child: Column(
          children: [
            // ═════════ TOP BAR ═════════
            Padding(
              padding: const EdgeInsets.all(16),

              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),

                    icon: const Icon(
                      Icons.close,
                      size: 28,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),

                      child: LinearProgressIndicator(
                        value: progress,

                        minHeight: 14,

                        backgroundColor: const Color(0xFFE5E5E5),

                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Text(
                    '${_index + 1}/${_questions.length}',

                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // ═════════ CONTENT ═════════
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),

                        borderRadius: BorderRadius.circular(999),
                      ),

                      child: const Text(
                        AppStrings.questionLabel,

                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      q.questionText,

                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ═════════ QUESTION IMAGE ═════════
                    // TRACING questions skip the static preview here —
                    // the same image is shown as the interactive guide
                    // inside TracingCanvasWidget, so rendering it twice
                    // would create a duplicate visual.
                    if (q.imageUrl != null &&
                        q.imageUrl!.trim().isNotEmpty &&
                        q.type != 'TRACING')
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),

                        child: Image.network(
                          '$kBaseUrl${q.imageUrl!}',

                          height: 220,

                          width: double.infinity,

                          fit: BoxFit.cover,

                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 220,

                              alignment: Alignment.center,

                              color: Colors.grey.shade200,

                              child: const Icon(
                                Icons.broken_image,
                                size: 50,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ═════════ OPTIONS ═════════
                    if (q.type != 'WRITE_ANSWER' &&
                        q.type != 'SHORT_ANSWER' &&
                        q.type != 'TRACING' &&
                        q.options.isNotEmpty)
                      ...q.options.map((option) {
                        final optionValue = option.imageUrl.isNotEmpty
                            ? option.imageUrl
                            : option.text;

                        final isSelected = _selectedAnswer == optionValue;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),

                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedAnswer = optionValue;
                              });
                            },

                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),

                              width: double.infinity,

                              padding: const EdgeInsets.all(18),

                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : Colors.white,

                                borderRadius: BorderRadius.circular(20),

                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFFEAEAEA),

                                  width: 2,
                                ),
                              ),

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  // IMAGE
                                  if (option.imageUrl.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),

                                      child: Image.network(
                                        '$kBaseUrl${option.imageUrl}',

                                        height: 140,

                                        width: double.infinity,

                                        fit: BoxFit.cover,

                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                height: 140,

                                                alignment: Alignment.center,

                                                color: Colors.grey.shade200,

                                                child: const Icon(
                                                  Icons.broken_image,
                                                  size: 40,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                      ),
                                    ),

                                  // TEXT
                                  if (option.text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),

                                      child: Text(
                                        option.text,

                                        style: TextStyle(
                                          fontSize: 18,

                                          fontWeight: FontWeight.w700,

                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.black,
                                        ),
                                      ),
                                    ),

                                  if (isSelected)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 10),

                                      child: Icon(
                                        Icons.check_circle,

                                        color: AppColors.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                    // ═════════ WRITE ANSWER ═════════
                    if (q.type == 'WRITE_ANSWER' || q.type == 'SHORT_ANSWER')
                      TextField(
                        controller: _writeController,

                        decoration: InputDecoration(
                          hintText: AppStrings.questionWriteHint,

                          filled: true,

                          fillColor: Colors.white,

                          contentPadding: const EdgeInsets.all(18),

                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),

                            borderSide: const BorderSide(
                              color: Color(0xFFEAEAEA),
                            ),
                          ),
                        ),

                        onChanged: (value) {
                          _selectedAnswer = value;
                        },
                      ),

                    // ═════════ TRACING CANVAS (inline) ═════════
                    if (q.type == 'TRACING') ...[
                      SizedBox(
                        height: 300,
                        child: Card(
                          elevation: 4,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: TracingCanvasWidget(
                            key: _tracingCanvasKey,
                            question: TracingQuestion(
                              id: q.id.toString(),
                              displayText: q.questionText,
                              instruction: AppStrings.questionTraceInstruction,
                              category: TracingCategory.number,
                              guideStrokes: const [],
                              imageUrl: q.imageUrl,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () =>
                              _tracingCanvasKey.currentState?.clear(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(AppStrings.tracingClear),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ═════════ BUTTON ═════════
            Container(
              padding: const EdgeInsets.all(24),

              decoration: const BoxDecoration(
                color: Colors.white,

                border: Border(
                  top: BorderSide(color: Color(0xFFEAEAEA), width: 2),
                ),
              ),

              child: FatButton(
                label: _index == _questions.length - 1
                    ? AppStrings.finish
                    : AppStrings.continueBtn,

                onPressed: () async {
                  if (q.type == 'TRACING') {
                    final canvas = _tracingCanvasKey.currentState;
                    if (canvas == null || canvas.validStrokes.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(AppStrings.questionDrawFirst),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    // Save the tracing answer (always marked correct server-side)
                    try {
                      await QuestionService.instance.saveAnswer(
                        questionId: q.id,
                        lessonId: int.parse(widget.lessonId),
                        answer: 'TRACED',
                        questionType: 'TRACING',
                      );
                    } catch (_) {
                      // Non-fatal — continue even if save fails
                    }
                    canvas.clear();
                    if (_index < _questions.length - 1) {
                      setState(() {
                        _index++;
                        _selectedAnswer = null;
                        _writeController.clear();
                      });
                    } else {
                      _completeAndShowQuizDialog();
                    }
                    return;
                  }

                  if (_selectedAnswer == null ||
                      _selectedAnswer!.trim().isEmpty) {
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);

                  bool isCorrect = false;
                  try {
                    final result = await QuestionService.instance.saveAnswer(
                      questionId: q.id,

                      lessonId: int.parse(widget.lessonId),

                      answer: _selectedAnswer!,

                      questionType: q.type ?? '',
                    );

                    isCorrect = result.isCorrect;

                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: isCorrect ? Colors.green : Colors.red,
                        content: Text(
                          isCorrect
                              ? AppStrings.questionCorrect
                              : AppStrings.questionWrong,
                        ),
                      ),
                    );
                  } catch (e) {
                    // API failed — show error but continue to next question
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }

                  await Future.delayed(const Duration(seconds: 1));

                  if (_index < _questions.length - 1) {
                    setState(() {
                      _index++;

                      _selectedAnswer = null;

                      _writeController.clear();
                    });
                  } else {
                    _completeAndShowQuizDialog();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
