// ════════════════════════════════════════════════════════════════════════════
// QUESTION SCREEN — Lesson question flow
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _writeController = TextEditingController();
  final _tracingKey = GlobalKey<TracingCanvasState>();
  bool _readingCompleted = false;

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

  // Returns true when every option has an image and no text — triggers grid.
  bool _allImageOnly(List<QuestionOption> opts) =>
      opts.isNotEmpty &&
      opts.every((o) => o.imageUrl.isNotEmpty && o.text.isEmpty);

  // True for any question type that shows selectable options.
  // FILL_BLANK is excluded even when it has options, because the lesson flow
  // renders it as a write field (no word-bank chip UI in the lesson screen).
  bool _isChoiceType(QuestionModel q) =>
      q.type != 'SHORT_ANSWER' &&
      q.type != 'WRITE_ANSWER' &&
      q.type != 'FILL_BLANK' &&
      q.type != 'TRACING' &&
      q.options.isNotEmpty;

  // ── Data loading ──────────────────────────────────────────────────────────

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
      print('🚀 BEFORE SERVICE');

      final qs = await QuestionService.instance.getQuestionsByLesson(id);

      print('🚀 AFTER SERVICE');
      print('Questions Loaded = ${qs.length}');
      setState(() => _questions = qs);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Completion ────────────────────────────────────────────────────────────

  Future<void> _completeAndShowQuizDialog() async {
    debugPrint('[QuestionScreen] _completeAndShowQuizDialog() entered');
    final lid = int.tryParse(widget.lessonId);
    if (lid != null) {
      try {
        final p = await SharedPreferences.getInstance();
        await LessonService.instance.completeLesson(
          lid,
          studentId: p.getInt('active_student_id'),
        );
      } catch (_) {}
    }
    await _showQuizDialog();
  }

  Future<void> _showQuizDialog() async {
    if (!mounted) return;

    final take = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
    if (take == true) {
      context.go('/quiz/${widget.lessonId}');
    } else {
      context.go('/home');
    }
  }

  // ── Answer handling ───────────────────────────────────────────────────────

  Future<void> _handleContinue(QuestionModel q) async {
    debugPrint('▶▶▶ _handleContinue: type=${q.type} id=${q.id}');
    debugPrint('     _selectedAnswer = "$_selectedAnswer"');

    // ── TRACING ────────────────────────────────────────────────
    if (q.type == 'TRACING') {
      final canvas = _tracingKey.currentState;
      if (canvas == null || canvas.validStrokes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.questionDrawFirst),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      debugPrint('     Submitting TRACING answer: "TRACED"');
      try {
        await QuestionService.instance.saveAnswer(
          questionId: q.id,
          lessonId: int.parse(widget.lessonId),
          answer: 'TRACED',
          questionType: 'TRACING',
        );
      } catch (_) {}
      canvas.clear();
      _advance();
      return;
    }

    // ── ALL OTHER TYPES ─────────────────────────────────────────
    if (_selectedAnswer == null || _selectedAnswer!.trim().isEmpty) {
      debugPrint(
        '     BLOCKED: _selectedAnswer is null or empty — not submitting',
      );
      return;
    }

    debugPrint(
      '     Submitting answer: "${_selectedAnswer!}" for type=${q.type}',
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await QuestionService.instance.saveAnswer(
        questionId: q.id,
        lessonId: int.parse(widget.lessonId),
        answer: _selectedAnswer!,
        questionType: q.type ?? '',
      );
      debugPrint(
        '     Result: isCorrect=${result.isCorrect} points=${result.pointsAwarded}',
      );
      _showResultBanner(messenger, result.isCorrect);
    } catch (e) {
      debugPrint('     ERROR submitting answer: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    await Future.delayed(const Duration(milliseconds: 950));
    _advance();
  }

  Future<void> _handleReadingStart(QuestionModel q) async {
    debugPrint('[QuestionScreen] _handleReadingStart called — q.id=${q.id} q.type=${q.type}');
    final readingText = (q.correctAnswer?.trim().isNotEmpty == true)
        ? q.correctAnswer!
        : q.questionText;
    _readingCompleted = false;
    debugPrint('[QuestionScreen] pushing /reading/${widget.lessonId} — readingText="$readingText"');
    await context.push(
      '/reading/${widget.lessonId}',
      extra: {
        'text': readingText,
        'questionId': q.id,
        'onComplete': () {
          debugPrint('[QuestionScreen] onComplete callback INVOKED — setting _readingCompleted=true');
          _readingCompleted = true;
        },
      },
    );
    debugPrint('[QuestionScreen] context.push returned — mounted=$mounted _readingCompleted=$_readingCompleted');
    if (!mounted) return;
    if (_readingCompleted) {
      debugPrint('[QuestionScreen] _readingCompleted=true → calling _advance()');
      _readingCompleted = false;
      _advance();
    } else {
      debugPrint('[QuestionScreen] _readingCompleted=false → NOT advancing (user dismissed without completing)');
    }
  }

  void _advance() {
    debugPrint('[QuestionScreen] _advance() — _index=$_index total=${_questions.length}');
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selectedAnswer = null;
        _writeController.clear();
      });
    } else {
      debugPrint('[QuestionScreen] _advance() → last question reached, calling _completeAndShowQuizDialog');
      _completeAndShowQuizDialog();
    }
  }

  void _showResultBanner(ScaffoldMessengerState messenger, bool correct) {
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: correct
            ? const Color(0xFF2E7D32)
            : const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        duration: const Duration(milliseconds: 900),
        content: Row(
          children: [
            Text(correct ? '🌟' : '💪', style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Text(
              correct ? AppStrings.questionCorrect : AppStrings.questionWrong,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('😕', style: TextStyle(fontSize: 52)),
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

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📭', style: TextStyle(fontSize: 52)),
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
                FatButton(
                  label: AppStrings.goBack,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final q = _questions[_index];
    print('========================');
    print('QUESTION ID = ${q.id}');
    print('QUESTION TEXT = ${q.questionText}');
    print('QUESTION TYPE = ${q.type}');
    print('OPTIONS COUNT = ${q.options.length}');
    final imageOnly = _allImageOnly(q.options);
    final progress = (_index + 1) / _questions.length;
    if (q.type == 'READING') {
      final readingText = (q.correctAnswer?.trim().isNotEmpty == true)
          ? q.correctAnswer!
          : q.questionText;

      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                index: _index,
                total: _questions.length,
                progress: progress,
                onClose: () => context.pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Question instruction text
                      Text(
                        q.questionText,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Target reading word / sentence
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFE8DCC8),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              offset: Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Text(
                          readingText,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.7,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _BottomBar(
          label: AppStrings.readingStart,
          onPressed: () => _handleReadingStart(q),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────
            _TopBar(
              index: _index,
              total: _questions.length,
              progress: progress,
              onClose: () => context.pop(),
            ),

            // ── Scrollable content ────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question text
                    Text(
                      q.questionText,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Context image (shown above options when question has one)
                    if (q.imageUrl != null &&
                        q.imageUrl!.trim().isNotEmpty &&
                        q.type != 'TRACING') ...[
                      _ContextImage(url: '$kBaseUrl${q.imageUrl!}'),
                      const SizedBox(height: 20),
                    ],

                    // ── Image grid (2 columns, no card background) ──
                    if (_isChoiceType(q) && imageOnly)
                      _ImageGrid(
                        options: q.options,
                        selected: _selectedAnswer,
                        onSelect: (v) => setState(() => _selectedAnswer = v),
                      ),

                    // ── Text/mixed option cards ─────────────────────
                    if (_isChoiceType(q) && !imageOnly)
                      _TextOptions(
                        options: q.options,
                        selected: _selectedAnswer,
                        onSelect: (v) => setState(() => _selectedAnswer = v),
                      ),

                    // ── Write answer (SHORT_ANSWER / WRITE_ANSWER / FILL_BLANK) ──
                    if (q.type == 'WRITE_ANSWER' ||
                        q.type == 'SHORT_ANSWER' ||
                        q.type == 'FILL_BLANK')
                      _WriteField(
                        controller: _writeController,
                        onChanged: (v) => setState(() => _selectedAnswer = v),
                      ),

                    // ── Tracing canvas ──────────────────────────────
                    if (q.type == 'TRACING') ...[
                      _TracingArea(canvasKey: _tracingKey, question: q),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _tracingKey.currentState?.clear(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(AppStrings.tracingClear),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            backgroundColor: AppColors.danger.withValues(
                              alpha: 0.09,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── CTA button ────────────────────────────────────────
            _BottomBar(
              label: _index == _questions.length - 1
                  ? AppStrings.finish
                  : AppStrings.continueBtn,
              onPressed: () => _handleContinue(q),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TOP BAR
// ═════════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.index,
    required this.total,
    required this.progress,
    required this.onClose,
  });

  final int index;
  final int total;
  final double progress;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Close button — rounded white tile instead of bare IconButton
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Progress bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 13,
                backgroundColor: const Color(0xFFE5E5E5),
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Question counter badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${index + 1}/$total',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CONTEXT IMAGE — question-level image shown above the options
// ═════════════════════════════════════════════════════════════════════════════

class _ContextImage extends StatelessWidget {
  const _ContextImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.network(
        url,
        height: 200,
        width: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Container(
          height: 200,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.broken_image_rounded,
            size: 48,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// IMAGE GRID — 2-column layout for all-image-only questions
// No card background. PNG shown directly with BoxFit.contain.
// ═════════════════════════════════════════════════════════════════════════════

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<QuestionOption> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.88, // slightly taller to fit the check icon below
      ),
      itemCount: options.length,
      itemBuilder: (_, i) {
        final opt = options[i];
        return _ImageOptionTile(
          imageUrl: '$kBaseUrl${opt.imageUrl}',
          isSelected: selected == opt.imageUrl,
          onTap: () => onSelect(opt.imageUrl),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single image tile — bare PNG, scale + glow on selection, check below.
// ─────────────────────────────────────────────────────────────────────────────

class _ImageOptionTile extends StatelessWidget {
  const _ImageOptionTile({
    required this.imageUrl,
    required this.isSelected,
    required this.onTap,
  });

  final String imageUrl;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: Column(
          children: [
            // Image — fills the top portion of the cell
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.52),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // The image itself — transparent PNG friendly
                      Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_rounded,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      // Orange border overlay fades in when selected
                      AnimatedOpacity(
                        opacity: isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 3.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Check icon below — always reserves 34px; transparent when idle
            const SizedBox(height: 8),
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TEXT OPTIONS — vertical card list for text or mixed (image+text) options
// ═════════════════════════════════════════════════════════════════════════════

class _TextOptions extends StatelessWidget {
  const _TextOptions({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<QuestionOption> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.map((opt) {
        // Always prefer text as the answer identifier — correctAnswer in the DB
        // is always stored as text. Only fall back to imageUrl for image-only
        // options that have no text label.
        final value = opt.text.isNotEmpty ? opt.text : opt.imageUrl;
        final sel = selected == value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: () => onSelect(value),
            child: AnimatedScale(
              scale: sel ? 1.02 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary.withValues(alpha: 0.09)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: sel ? AppColors.primary : const Color(0xFFE5E5E5),
                    width: sel ? 2.5 : 2.0,
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.20),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    // Animated radio circle
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: sel
                              ? AppColors.primary
                              : const Color(0xFFCCCCCC),
                          width: 2.5,
                        ),
                      ),
                      child: sel
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 17,
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),

                    // Option content: image, text, or both
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (opt.imageUrl.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: opt.text.isNotEmpty ? 10 : 0,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  '$kBaseUrl${opt.imageUrl}',
                                  height: 110,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    height: 110,
                                    color: Colors.grey.shade100,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.broken_image_rounded,
                                      size: 36,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (opt.text.isNotEmpty)
                            Text(
                              opt.text,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WRITE FIELD — styled text input for WRITE_ANSWER / SHORT_ANSWER
// ═════════════════════════════════════════════════════════════════════════════

class _WriteField extends StatelessWidget {
  const _WriteField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textDirection: TextDirection.rtl,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: AppStrings.questionWriteHint,
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2.5),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TRACING AREA — canvas wrapped in a styled container
// ═════════════════════════════════════════════════════════════════════════════

class _TracingArea extends StatelessWidget {
  const _TracingArea({required this.canvasKey, required this.question});

  final GlobalKey<TracingCanvasState> canvasKey;
  final QuestionModel question;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.30),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: TracingCanvasWidget(
          key: canvasKey,
          question: TracingQuestion(
            id: question.id.toString(),
            displayText: question.questionText,
            instruction: AppStrings.questionTraceInstruction,
            category: TracingCategory.number,
            guideStrokes: const [],
            imageUrl: question.imageUrl,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BOTTOM BAR — CTA button with soft shadow instead of a hard border
// ═════════════════════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: FatButton(label: label, onPressed: onPressed),
    );
  }
}
