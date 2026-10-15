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
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/adaptive_quiz_models.dart';
import '../services/adaptive_quiz_service.dart';
import '../services/api_client.dart';
import '../widgets/tts_speaker_button.dart';

// ── Premium color palette (scoped to this file) ───────────────────────────────
const _cPD = Color(0xFF111844); // primary dark — top bar, submit button
const _cP = Color(0xFF4B5694); // primary — progress fill, selection accent
const _cS = Color(0xFF7288AE); // secondary — hints, secondary actions
const _cBg = Color(0xFFF8FAFC); // page background
const _cT = Color(0xFF0F172A); // text primary
const _cTS = Color(0xFF64748B); // text secondary
const _cOk = Color(0xFF16A34A); // success — صح / correct
const _cErr = Color(0xFFDC2626); // error — خطأ / wrong

// ─────────────────────────────────────────────────────────────────────────────

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

  // ── Active child studentId (non-null only in parent mode) ────
  int? _studentId;

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

    final prefs = await SharedPreferences.getInstance();
    _studentId = prefs.getInt('active_student_id');
    debugPrint('[QuizScreen] activeStudentId=$_studentId lessonId=$lessonId');

    try {
      final payload = await AdaptiveQuizService.instance.generateOrResume(
        lessonId,
        studentId: _studentId,
      );

      for (final q in payload.questions) {
        debugPrint(
          'QUESTION => index=${q.questionIndex} text=${q.questionText}',
        );
      }

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

  bool get _hintAvailable =>
      _perQHintsRemaining > 0 && _totalHintsRemaining > 0 && !_loadingHint;

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

      if (e.statusCode == 429) {
        setState(() {
          _hintLevels[qIdx] = 3;
          _totalHintsUsed = 10;
        });
      }

      final msg = e.statusCode == 429
          ? (e.message.isNotEmpty ? e.message : AppStrings.adaptiveHintLimit429)
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

    final answeredCount = _answers.values
        .where((a) => a.trim().isNotEmpty)
        .length;
    if (answeredCount * 2 < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(AppStrings.adaptiveQuizMinAnswers),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: _cErr,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
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
        studentId: _studentId,
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
            backgroundColor: _cErr,
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
              style: TextStyle(color: _cErr, fontWeight: FontWeight.w900),
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
    final answeredCount = _answers.values
        .where((a) => a.trim().isNotEmpty)
        .length;

    return Scaffold(
      backgroundColor: _cBg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              index: _idx,
              total: total,
              progress: progress,
              answeredCount: answeredCount,
              onClose: _showCloseDialog,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Question card with TTS
                    _QuestionCard(questionText: q.questionText),
                    const SizedBox(height: 16),

                    // Hint row
                    _HintRow(
                      loading: _loadingHint,
                      available: _hintAvailable,
                      perQRemaining: _perQHintsRemaining,
                      totalRemaining: _totalHintsRemaining,
                      cachedHint: _hintTexts[q.questionIndex],
                      onTap: _fetchHint,
                      onStronger: _hintAvailable ? _fetchHint : null,
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              // Close button
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _cBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.close_rounded, size: 20, color: _cTS),
                ),
              ),
              const SizedBox(width: 14),

              // Question counter badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _cP.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'السؤال ${index + 1} من $total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _cP,
                  ),
                ),
              ),

              const Spacer(),

              // Answered count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _cOk.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 14,
                      color: _cOk,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$answeredCount/$total',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _cOk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Gradient progress bar
          LayoutBuilder(
            builder: (_, constraints) {
              return Stack(
                children: [
                  Container(
                    width: constraints.maxWidth,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOut,
                    width: constraints.maxWidth * progress,
                    height: 7,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_cPD, _cP],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// QUESTION CARD
// ════════════════════════════════════════════════════════════════════════════

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.questionText});

  final String questionText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: _cP.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  questionText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.6,
                    color: _cT,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: _cBg,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TtsSpeakerButton(
                  text: questionText,
                  audioType: 'explanation',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HINT ROW — button + inline remaining count + cached hint preview
// ════════════════════════════════════════════════════════════════════════════

class _HintRow extends StatelessWidget {
  const _HintRow({
    required this.loading,
    required this.available,
    required this.perQRemaining,
    required this.totalRemaining,
    required this.onTap,
    this.cachedHint,
    this.onStronger,
  });

  final bool loading;
  final bool available;
  final int perQRemaining;
  final int totalRemaining;
  final String? cachedHint;
  final VoidCallback onTap;
  final VoidCallback? onStronger;

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: disabled
                  ? const Color(0xFFF1F5F9)
                  : _cS.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: disabled
                    ? const Color(0xFFCBD5E1)
                    : _cS.withValues(alpha: 0.50),
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
                      color: _cS,
                    ),
                  )
                else
                  Icon(
                    disabled
                        ? Icons.lock_outline_rounded
                        : Icons.lightbulb_outline_rounded,
                    size: 15,
                    color: disabled ? _cTS : _cS,
                  ),
                const SizedBox(width: 6),
                Text(
                  disabled
                      ? AppStrings.adaptiveHintExhausted
                      : AppStrings.adaptiveHintButton,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: disabled ? _cTS : _cS,
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
              fontWeight: FontWeight.w600,
              color: _cTS,
            ),
          ),
        ],

        // Cached hint preview button
        if (cachedHint != null && cachedHint!.isNotEmpty) ...[
          const Spacer(),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (sheetCtx) => _HintBottomSheet(
                hint: cachedHint!,
                perQRemaining: perQRemaining,
                totalRemaining: totalRemaining,
                onStronger: onStronger != null
                    ? () {
                        Navigator.pop(sheetCtx);
                        onStronger!();
                      }
                    : null,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _cS.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _cS.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.visibility_outlined, size: 13, color: _cS),
                  SizedBox(width: 5),
                  Text(
                    'عرض التلميح',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _cS,
                    ),
                  ),
                ],
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _cS.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 20,
                    color: _cS,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  AppStrings.adaptiveHintTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _cT,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppStrings.adaptiveHintRemainingPerQ(perQRemaining),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _cTS,
                      ),
                    ),
                    Text(
                      AppStrings.adaptiveHintRemainingTotal(totalRemaining),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _cTS,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Hint content card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.7,
                      color: _cT,
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TtsSpeakerButton(text: hint, audioType: 'hint'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stronger hint button
            if (moreAvailable) ...[
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: onStronger,
                  icon: const Icon(
                    Icons.lightbulb_rounded,
                    size: 18,
                    color: _cS,
                  ),
                  label: const Text(
                    AppStrings.adaptiveHintStronger,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _cS,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _cS, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Close button
            SizedBox(
              height: 50,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  AppStrings.adaptiveHintClose,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _cTS,
                  ),
                ),
              ),
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
// MCQ — vertical card list with animated selection
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
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => onSelect(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: sel ? _cP.withValues(alpha: 0.07) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: sel ? _cP : const Color(0xFFE2E8F0),
                  width: sel ? 2.0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: sel
                        ? _cP.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: sel ? 14 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Selection indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel ? _cP : Colors.transparent,
                      border: Border.all(
                        color: sel ? _cP : const Color(0xFFCBD5E1),
                        width: 2.0,
                      ),
                    ),
                    child: sel
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: sel ? _cP : _cT,
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
// TRUE / FALSE — two large outlined cards
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
    final choices = options.isNotEmpty ? options : ['صح', 'خطأ'];

    return Row(
      children: choices.map((choice) {
        final sel = selected == choice;
        final isFirst = choice == choices.first;
        final activeColor = isFirst ? _cOk : _cErr;
        final icon = isFirst
            ? Icons.check_circle_outline_rounded
            : Icons.cancel_outlined;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: isFirst ? 0 : 8,
              right: isFirst ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () => onSelect(choice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 90,
                decoration: BoxDecoration(
                  color: sel
                      ? activeColor.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: sel ? activeColor : const Color(0xFFE2E8F0),
                    width: sel ? 2.0 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: sel
                          ? activeColor.withValues(alpha: 0.14)
                          : Colors.black.withValues(alpha: 0.03),
                      blurRadius: sel ? 14 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 26,
                      color: sel ? activeColor : const Color(0xFFCBD5E1),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      choice,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: sel ? activeColor : _cT,
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
// SHORT ANSWER — premium RTL text field
// ────────────────────────────────────────────────────────────────────────────

class _ShortAnswerInput extends StatelessWidget {
  const _ShortAnswerInput({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textDirection: TextDirection.rtl,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: _cT,
      ),
      maxLines: 4,
      minLines: 2,
      decoration: InputDecoration(
        hintText: AppStrings.questionWriteHint,
        hintStyle: const TextStyle(
          color: _cTS,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _cP, width: 2.0),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: submitting
          ? const SizedBox(
              height: 56,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: _cP,
                        strokeWidth: 2.5,
                      ),
                    ),
                    SizedBox(width: 14),
                    Text(
                      AppStrings.adaptiveQuizSubmitting,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _cTS,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLast ? onSubmit : onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cPD,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isLast ? 'إرسال الإجابات' : AppStrings.continueBtn,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOADING STATE
// ════════════════════════════════════════════════════════════════════════════

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _cBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 56, color: _cP),
            SizedBox(height: 24),
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(color: _cP, strokeWidth: 3),
            ),
            SizedBox(height: 18),
            Text(
              AppStrings.adaptiveQuizLoading,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _cTS,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ERROR STATE
// ════════════════════════════════════════════════════════════════════════════

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
      backgroundColor: _cBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _cErr.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 36,
                  color: _cErr,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _cTS,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cPD,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    AppStrings.retry,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _cTS,
                    side: const BorderSide(
                      color: Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    AppStrings.goBack,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
