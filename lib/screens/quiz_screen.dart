// ════════════════════════════════════════════════════════════════════════════
// quiz_screen.dart — Adaptive Quiz Orchestrator
// ════════════════════════════════════════════════════════════════════════════
//
// Responsibilities:
//   • Load (or resume) an adaptive quiz via GET /api/quiz/adaptive/{lessonId}
//   • Render one question at a time with type-aware input:
//       MCQ         → radio option cards
//       TRUE_FALSE  → two large choice buttons
//       SHORT_ANSWER → RTL text field
//   • Manage a per-question / per-quiz hint system with backend-enforced limits
//       (3 per question, 10 per quiz). Gracefully handles HTTP 429.
//   • Collect all answers locally (Map<questionIndex, answer>)
//   • Validate ≥ 50% answered before allowing submission
//   • Submit batch via POST /api/quiz/adaptive/{attemptId}/submit
//   • Navigate to AdaptiveQuizResultScreen with the full result
//
// Backend endpoints:
//   GET  /api/quiz/adaptive/{lessonId}
//   POST /api/quiz/adaptive/{attemptId}/submit
//   GET  /api/quiz/adaptive/{attemptId}/question/{questionIndex}/hint?level=N
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_strings.dart';
import '../models/adaptive_quiz_models.dart';
import '../services/adaptive_quiz_service.dart';
import '../services/api_client.dart';
import '../theme/theme.dart';
import '../widgets/fat_button.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // ── Loading / error ─────────────────────────────────────────
  bool _loading = true;
  String? _error;

  // ── Quiz data ────────────────────────────────────────────────
  AdaptiveQuizPayload? _payload;

  // ── Current question ─────────────────────────────────────────
  int _idx = 0;

  // ── Answers: questionIndex → answer string ──────────────────
  final Map<int, String> _answers = {};

  // ── Hint state ───────────────────────────────────────────────
  // Tracks how many hint levels have been fetched per question (0–3).
  final Map<int, int> _hintLevels = {};
  int _totalHintsUsed = 0;
  bool _loadingHint = false;
  // Caches the last fetched hint per question for display in the sheet.
  final Map<int, String> _hintTexts = {};

  // ── Submission ───────────────────────────────────────────────
  bool _submitting = false;

  // ── Write controller (SHORT_ANSWER) ─────────────────────────
  final TextEditingController _writeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _writeCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  // DATA LOADING
  // ════════════════════════════════════════════════════════════

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final lessonId = int.tryParse(widget.lessonId);
    if (lessonId == null) {
      setState(() {
        _error = 'معرف الدرس غير صالح.';
        _loading = false;
      });
      return;
    }

    try {
      final payload =
          await AdaptiveQuizService.instance.generateOrResume(lessonId);

      if (payload.questions.isEmpty) {
        setState(() {
          _error = AppStrings.adaptiveQuizNoQuestions;
          _loading = false;
        });
        return;
      }

      setState(() => _payload = payload);
    } on ApiException catch (e) {
      setState(() => _error = _apiErrorMsg(e));
    } catch (_) {
      setState(() => _error = AppStrings.adaptiveNetworkError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _apiErrorMsg(ApiException e) {
    if (e.statusCode == 401 || e.statusCode == 403) {
      return AppStrings.adaptiveUnauthorized;
    }
    if (e.statusCode >= 500) return AppStrings.adaptiveServerError;
    return e.message.isNotEmpty ? e.message : AppStrings.adaptiveNetworkError;
  }

  // ════════════════════════════════════════════════════════════
  // HINT SYSTEM
  // ════════════════════════════════════════════════════════════

  int _hintLevelFor(int qIdx) => _hintLevels[qIdx] ?? 0;

  int get _perQHintsRemaining => 3 - _hintLevelFor(_idx);
  int get _totalHintsRemaining => 10 - _totalHintsUsed;

  // Button is active only when both quotas have room and no fetch is in-flight.
  bool get _hintAvailable =>
      _perQHintsRemaining > 0 &&
      _totalHintsRemaining > 0 &&
      !_loadingHint;

  Future<void> _fetchHint() async {
    if (!_hintAvailable || _payload == null) return;

    final attemptId = _payload!.attemptId;
    final qIdx = _idx;
    final level = _hintLevelFor(qIdx) + 1;

    setState(() => _loadingHint = true);

    try {
      final hint = await AdaptiveQuizService.instance.getHint(
        attemptId,
        qIdx,
        level: level,
      );

      if (!mounted) return;
      setState(() {
        _hintLevels[qIdx] = level;
        _totalHintsUsed++;
        _hintTexts[qIdx] = hint;
      });

      _showHintSheet(hint, qIdx);
    } on ApiException catch (e) {
      if (!mounted) return;

      // 429 means a limit was hit — exhaust the relevant quota so the button
      // is disabled without requiring a second failing request.
      if (e.statusCode == 429) {
        setState(() {
          _hintLevels[qIdx] = 3; // per-question exhausted
          _totalHintsUsed = 10;  // also treat as quiz-level exhausted
        });
      }

      final msg =
          e.statusCode == 429
              ? (e.message.isNotEmpty
                  ? e.message
                  : AppStrings.adaptiveHintLimit429)
              : AppStrings.adaptiveHintFailed;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: const Color(0xFF5C5C5C),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(AppStrings.adaptiveHintFailed),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingHint = false);
    }
  }

  void _showHintSheet(String hint, int qIdx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HintBottomSheet(
        hint: hint,
        perQRemaining: _perQHintsRemaining,
        totalRemaining: _totalHintsRemaining,
        onStronger: _hintAvailable
            ? () {
                Navigator.pop(context);
                _fetchHint();
              }
            : null,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // ANSWER HANDLING
  // ════════════════════════════════════════════════════════════

  void _onSelect(String value) => setState(() => _answers[_idx] = value);

  void _onWriteChanged(String value) {
    _answers[_idx] = value;
  }

  // ════════════════════════════════════════════════════════════
  // NAVIGATION
  // ════════════════════════════════════════════════════════════

  void _advance() {
    final nextIdx = _idx + 1;
    final q = _payload!.questions[nextIdx];

    // Pre-fill the write controller if the next question has a cached answer.
    if (q.type == 'SHORT_ANSWER') {
      _writeCtrl.text = _answers[q.questionIndex] ?? '';
    } else {
      _writeCtrl.clear();
    }

    setState(() => _idx = nextIdx);
  }

  // ════════════════════════════════════════════════════════════
  // SUBMISSION
  // ════════════════════════════════════════════════════════════

  Future<void> _submit() async {
    final payload = _payload!;
    final total = payload.questions.length;

    // Validate ≥ 50% answered.
    final answeredCount =
        _answers.values.where((a) => a.trim().isNotEmpty).length;
    if (answeredCount * 2 < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppStrings.adaptiveQuizMinAnswers),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // Build answer list — include all questions, empty string for skipped.
      final answers = payload.questions.map((q) {
        return AdaptiveAnswer(
          questionIndex: q.questionIndex,
          answer: _answers[q.questionIndex]?.trim() ?? '',
        );
      }).toList();

      final result = await AdaptiveQuizService.instance.submit(
        payload.attemptId,
        answers,
        total,
      );

      if (!mounted) return;
      context.go(
        '/adaptive-quiz-result',
        extra: {
          'result': result,
          'difficulty': payload.difficulty,
          'focusSkills': payload.focusSkills,
          'lessonId': widget.lessonId,
        },
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_apiErrorMsg(e)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFC62828),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(AppStrings.adaptiveNetworkError),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  // CLOSE DIALOG
  // ════════════════════════════════════════════════════════════

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

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _LoadingState();

    if (_error != null || _payload == null) {
      return _ErrorState(
        message: _error ?? AppStrings.adaptiveQuizNoQuestions,
        onRetry: _load,
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      );
    }

    final payload = _payload!;
    final q = payload.questions[_idx];
    final total = payload.questions.length;
    final isLast = _idx == total - 1;
    final progress = (_idx + 1) / total;
    final answeredCount =
        _answers.values.where((a) => a.trim().isNotEmpty).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: close + progress bar + question counter
            _TopBar(
              index: _idx,
              total: total,
              progress: progress,
              answeredCount: answeredCount,
              onClose: _showCloseDialog,
            ),

            // Scrollable question area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question text
                    Text(
                      q.questionText,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.55,
                        color: AppColors.textPrimary,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 14),

                    // Hint row
                    _HintRow(
                      loading: _loadingHint,
                      available: _hintAvailable,
                      perQRemaining: _perQHintsRemaining,
                      totalRemaining: _totalHintsRemaining,
                      cachedHint: _hintTexts[q.questionIndex],
                      onTap: _fetchHint,
                    ),
                    const SizedBox(height: 24),

                    // Type-specific input
                    _QuestionInput(
                      question: q,
                      currentAnswer: _answers[q.questionIndex],
                      writeController: _writeCtrl,
                      onSelect: _onSelect,
                      onWriteChanged: _onWriteChanged,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom action bar
            _BottomBar(
              isLast: isLast,
              submitting: _submitting,
              onNext: isLast ? null : _advance,
              onSubmit: isLast ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TOP BAR
// ════════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.index,
    required this.total,
    required this.progress,
    required this.answeredCount,
    required this.onClose,
  });

  final int index;
  final int total;
  final double progress;
  final int answeredCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Close button
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

          // "answered / total" counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$answeredCount/$total',
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

// ════════════════════════════════════════════════════════════════════════════
// HINT ROW — button + inline remaining count
// ════════════════════════════════════════════════════════════════════════════

class _HintRow extends StatelessWidget {
  const _HintRow({
    required this.loading,
    required this.available,
    required this.perQRemaining,
    required this.totalRemaining,
    required this.onTap,
    this.cachedHint,
  });

  final bool loading;
  final bool available;
  final int perQRemaining;
  final int totalRemaining;
  final String? cachedHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = !available && !loading;

    return Row(
      children: [
        // Hint pill button
        GestureDetector(
          onTap: available ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: disabled
                  ? const Color(0xFFF0F0F0)
                  : AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: disabled ? const Color(0xFFDDDDDD) : AppColors.gold,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  )
                else
                  Text(
                    disabled ? '🔒' : '💡',
                    style: const TextStyle(fontSize: 14),
                  ),
                const SizedBox(width: 6),
                Text(
                  disabled
                      ? AppStrings.adaptiveHintExhausted
                      : AppStrings.adaptiveHintButton,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: disabled ? AppColors.textSecondary : AppColors.flame,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (!disabled) ...[
          const SizedBox(width: 10),
          Text(
            AppStrings.adaptiveHintRemainingPerQ(perQRemaining),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],

        // Show previously fetched hint preview if available
        if (cachedHint != null && cachedHint!.isNotEmpty) ...[
          const Spacer(),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => _HintBottomSheet(
                hint: cachedHint!,
                perQRemaining: perQRemaining,
                totalRemaining: totalRemaining,
                onStronger: available ? onTap : null,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.30),
                ),
              ),
              child: const Text(
                'عرض التلميح 👁',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HINT BOTTOM SHEET
// ════════════════════════════════════════════════════════════════════════════

class _HintBottomSheet extends StatelessWidget {
  const _HintBottomSheet({
    required this.hint,
    required this.perQRemaining,
    required this.totalRemaining,
    this.onStronger,
  });

  final String hint;
  final int perQRemaining;
  final int totalRemaining;
  final VoidCallback? onStronger;

  @override
  Widget build(BuildContext context) {
    final moreAvailable = onStronger != null;

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Text(
                  AppStrings.adaptiveHintTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                // Remaining indicators
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppStrings.adaptiveHintRemainingPerQ(perQRemaining),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      AppStrings.adaptiveHintRemainingTotal(totalRemaining),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Hint text card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
              ),
              child: Text(
                hint,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.6,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 16),

            // "Stronger hint" action
            if (moreAvailable) ...[
              FatButton(
                label: AppStrings.adaptiveHintStronger,
                color: FatColor.gold,
                onPressed: onStronger,
              ),
              const SizedBox(height: 10),
            ],

            FatButton(
              label: AppStrings.adaptiveHintClose,
              color: FatColor.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// QUESTION INPUT — dispatches to the correct sub-widget by question type
// ════════════════════════════════════════════════════════════════════════════

class _QuestionInput extends StatelessWidget {
  const _QuestionInput({
    required this.question,
    required this.currentAnswer,
    required this.writeController,
    required this.onSelect,
    required this.onWriteChanged,
  });

  final AdaptiveQuizItem question;
  final String? currentAnswer;
  final TextEditingController writeController;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onWriteChanged;

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case 'TRUE_FALSE':
        return _TrueFalseInput(
          options: question.options,
          selected: currentAnswer,
          onSelect: onSelect,
        );
      case 'SHORT_ANSWER':
        return _ShortAnswerInput(
          controller: writeController,
          onChanged: onWriteChanged,
        );
      case 'MCQ':
      default:
        return _McqInput(
          options: question.options,
          selected: currentAnswer,
          onSelect: onSelect,
        );
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// MCQ — vertical card list with animated radio circle
// ────────────────────────────────────────────────────────────────────────────

class _McqInput extends StatelessWidget {
  const _McqInput({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.map((opt) {
        final sel = selected == opt;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GestureDetector(
            onTap: () => onSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color:
                    sel ? AppColors.primary.withValues(alpha: 0.09) : Colors.white,
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
                  // Radio indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
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
                            size: 16,
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: sel ? AppColors.primary : AppColors.textPrimary,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// TRUE / FALSE — two large horizontal buttons
// ────────────────────────────────────────────────────────────────────────────

class _TrueFalseInput extends StatelessWidget {
  const _TrueFalseInput({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // Use backend options if provided, otherwise fall back to Arabic defaults.
    final choices = options.isNotEmpty ? options : ['صح', 'خطأ'];

    return Row(
      children: choices.map((choice) {
        final sel = selected == choice;
        final isFirst = choice == choices.first;
        final activeColor = isFirst ? AppColors.secondary : AppColors.danger;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: isFirst ? 0 : 8,
              right: isFirst ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () => onSelect(choice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 80,
                decoration: BoxDecoration(
                  color: sel
                      ? activeColor.withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: sel ? activeColor : const Color(0xFFE5E5E5),
                    width: sel ? 2.5 : 2.0,
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
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
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isFirst ? '✓' : '✗',
                      style: TextStyle(
                        fontSize: 22,
                        color: sel ? activeColor : AppColors.textSecondary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      choice,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: sel ? activeColor : AppColors.textPrimary,
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

// ────────────────────────────────────────────────────────────────────────────
// SHORT ANSWER — styled RTL text field
// ────────────────────────────────────────────────────────────────────────────

class _ShortAnswerInput extends StatelessWidget {
  const _ShortAnswerInput({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textDirection: TextDirection.rtl,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      maxLines: 3,
      minLines: 1,
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
          borderSide:
              const BorderSide(color: AppColors.secondary, width: 2.5),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BOTTOM BAR
// ════════════════════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.isLast,
    required this.submitting,
    this.onNext,
    this.onSubmit,
  });

  final bool isLast;
  final bool submitting;
  final VoidCallback? onNext;
  final VoidCallback? onSubmit;

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
      child: submitting
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                    SizedBox(width: 14),
                    Text(
                      AppStrings.adaptiveQuizSubmitting,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : FatButton(
              label: isLast ? AppStrings.adaptiveResultRetry.isEmpty
                  ? 'إرسال الإجابات ✓'
                  : 'إرسال الإجابات ✓'
              : AppStrings.continueBtn,
              onPressed: isLast ? onSubmit : onNext,
            ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOADING / ERROR STATE WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 14),
            Text(
              AppStrings.adaptiveQuizLoading,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
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
              FatButton(label: AppStrings.retry, onPressed: onRetry),
              const SizedBox(height: 12),
              FatButton(
                label: AppStrings.goBack,
                color: FatColor.secondary,
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
