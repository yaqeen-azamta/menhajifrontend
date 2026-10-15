// ════════════════════════════════════════════════════════════════════════════
// QUESTION SCREEN — Lesson question flow
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/avatar_config.dart';
import '../models/question_model.dart';
import '../services/api_client.dart';
import '../services/lesson_service.dart';
import '../services/question_service.dart';
import '../services/reading_service.dart';
import '../services/voice_service.dart';
import '../theme/theme.dart';
import '../tracing/utils/tracing_helper.dart';
import '../widgets/avatar_companion/avatar_companion.dart';
import '../widgets/avatar_companion/avatar_messages.dart';
import '../widgets/fat_button.dart';
import '../widgets/questions/drag_drop_question.dart';
import '../widgets/quiz/question_callback.dart';
import '../widgets/quiz/question_renderer.dart';
import '../widgets/reading/accuracy_indicator_widget.dart';
import '../widgets/reading/reading_result_widget.dart';
import '../widgets/tts_speaker_button.dart';

// Reading sub-state inside QuestionScreen for READING question type.
enum _ReadingState { idle, recording, processing, result }

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key, required this.lessonId});
  final String lessonId;

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen>
    with SingleTickerProviderStateMixin {
  List<Question> _questions = [];
  bool _loading = true;
  String? _error;
  int _index = 0;
  String? _selectedAnswer;
  final _writeController = TextEditingController();
  bool _tracingCompleted = false;

  // Locks QuestionRenderer widgets (MATCHING / COLORING) after submission.
  bool _rendererLocked = false;

  // Set when opened via parent mode; null in direct-student mode.
  int? _activeStudentId;

  // Reading question inline state
  final _voice = VoiceService.instance;
  final _readingSvc = ReadingService.instance;
  _ReadingState _readingState = _ReadingState.idle;
  ReadingAssessmentResult? _readingResult;
  Timer? _recordingTimer;
  Duration _recordingElapsed = Duration.zero;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Avatar companion
  String? _avatarId;
  String _avatarEmoji = '🐰';
  String? _feedbackMsg;
  bool _showFeedbackCompanion = false;

  // DRAG_DROP: token → isCorrect, populated after a wrong-answer check.
  // null means no check has been done yet (no colour highlights).
  Map<String, bool>? _dragDropTokenStatus;

  // Hint state — reset each time the question advances.
  int _hintLevel = 0; // 0 = no hint fetched yet for this question
  int _remainingHints = 99; // sentinel meaning "unknown — assume available"
  bool _loadingHint = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.22,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadQuestions();
  }

  @override
  void dispose() {
    _writeController.dispose();
    _pulseCtrl.dispose();
    _recordingTimer?.cancel();
    if (_readingState == _ReadingState.recording) {
      _voice.stopRecording();
    }
    super.dispose();
  }

  // Returns true when every option has an image and no text — triggers grid.
  bool _allImageOnly(List<QuestionOption> opts) =>
      opts.isNotEmpty &&
      opts.every((o) => o.imageUrl.isNotEmpty && o.text.isEmpty);

  // True for any question type that shows selectable options.
  // FILL_BLANK is excluded even when it has options, because the lesson flow
  // renders it as a write field (no word-bank chip UI in the lesson screen).
  bool _isChoiceType(Question q) =>
      q.type != QuestionType.voiceAnswer &&
      q.type != QuestionType.writeAnswer &&
      q.type != QuestionType.fillBlank &&
      q.type != QuestionType.tracing &&
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

    final prefs = await SharedPreferences.getInstance();
    _activeStudentId = prefs.getInt('active_student_id');
    final avatarId = prefs.getString('active_student_avatar');
    _avatarId = avatarId;
    _avatarEmoji = AvatarConfig.resolve(avatarId).emoji;
    debugPrint(
      '[QuestionScreen] activeStudentId=$_activeStudentId lessonId=$id',
    );

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
    if (mounted) context.go('/lesson-complete/${widget.lessonId}');
  }

  // ── Answer handling ───────────────────────────────────────────────────────

  Future<void> _handleContinue(Question q) async {
    debugPrint('▶▶▶ _handleContinue: type=${q.type} id=${q.id}');
    debugPrint('     _selectedAnswer = "$_selectedAnswer"');

    // ── TRACING ────────────────────────────────────────────────
    // The game widget auto-advances via _onTracingGameFinished when the
    // user completes all strokes.  This branch handles the "Skip" button,
    // allowing the user to bypass tracing without completing it.
    if (q.type == QuestionType.tracing) {
      if (_tracingCompleted) return; // already handled by the game callback
      _tracingCompleted = true;
      debugPrint('     Submitting TRACING answer: "TRACED" (skipped)');
      try {
        await QuestionService.instance.saveAnswer(
          questionId: q.id,
          lessonId: int.parse(widget.lessonId),
          answer: 'TRACED',
          questionType: 'TRACING',
          studentId: _activeStudentId,
        );
      } catch (_) {}
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
        questionType: q.raw['type'] as String? ?? '',
        studentId: _activeStudentId,
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

  // ── QuestionRenderer answer handler (MATCHING / COLORING / DRAG_DROP) ──────

  Future<void> _handleRendererAnswer(Question q, SubmittedAnswer answer) async {
    if (_rendererLocked) return;
    setState(() => _rendererLocked = true);

    final messenger = ScaffoldMessenger.of(context);
    final typeStr = q.raw['type'] as String? ?? '';
    bool shouldAdvance = true;

    try {
      final result = await QuestionService.instance.saveAnswer(
        questionId: q.id,
        lessonId: int.parse(widget.lessonId),
        answer: answer.answer,
        questionType: typeStr,
        studentId: _activeStudentId,
      );
      debugPrint(
        '     Renderer result: isCorrect=${result.isCorrect} points=${result.pointsAwarded}',
      );

      // ── DRAG_DROP wrong answer: stay on question, highlight errors ─────
      if (q.type == QuestionType.dragDrop && !result.isCorrect) {
        if (mounted) {
          setState(() {
            _rendererLocked = false;
            _dragDropTokenStatus = _computeDragDropTokenStatus(
              answer.answer,
              result.correctAnswer ?? '',
            );
          });
          _showDragDropFeedbackBanner(
            messenger,
            result.feedback ?? 'إجابة خاطئة. حاول مجدداً.',
          );
        }
        shouldAdvance = false;
      } else {
        _showResultBanner(messenger, result.isCorrect);
      }
    } catch (e) {
      debugPrint('     ERROR in _handleRendererAnswer: $e');
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (!shouldAdvance) return;
    await Future.delayed(const Duration(milliseconds: 950));
    _advance();
  }

  /// Compute which tokens are correctly placed by comparing the submitted
  /// answer string to the correct answer returned by the backend.
  /// Mirrors the backend's normalizeDragDropPair logic so that space
  /// differences between the DB value and the submitted string don't
  /// cause correct placements to appear red.
  Map<String, bool> _computeDragDropTokenStatus(
    String submitted,
    String correct,
  ) {
    // Collapse internal whitespace and trim each side of '='.
    String normalizePair(String raw) {
      final t = raw.trim();
      final eq = t.indexOf('=');
      if (eq < 0) return t.replaceAll(RegExp(r'\s+'), ' ');
      final target = t.substring(0, eq).trim().replaceAll(RegExp(r'\s+'), ' ');
      final token = t.substring(eq + 1).trim().replaceAll(RegExp(r'\s+'), ' ');
      if (target.isEmpty || token.isEmpty) return '';
      return '$target=$token';
    }

    final correctPairs = <String>{};
    for (final p in correct.split(',')) {
      final n = normalizePair(p);
      if (n.isNotEmpty) correctPairs.add(n);
    }

    final result = <String, bool>{};
    for (final p in submitted.split(',')) {
      final n = normalizePair(p);
      if (n.isEmpty) continue;
      final eq = n.indexOf('=');
      if (eq > 0) {
        final token = n.substring(eq + 1);
        result[token] = correctPairs.contains(n);
      }
    }
    return result;
  }

  /// Show a persistent (3 s) error banner with the backend's feedback text
  /// and an avatar reaction — used only for DRAG_DROP wrong answers.
  void _showDragDropFeedbackBanner(
    ScaffoldMessengerState messenger,
    String feedback,
  ) {
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Text('💪', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                feedback,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted) {
      setState(() {
        _feedbackMsg = AvatarMessages.incorrect(_avatarId);
        _showFeedbackCompanion = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showFeedbackCompanion = false);
      });
    }
  }

  // ── Reading question — inline recording flow ──────────────────────────────

  Future<void> _startReadingRecording() async {
    if (_readingState != _ReadingState.idle) return;
    final granted = await _voice.startRecording();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.readingPermissionDenied),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    _pulseCtrl.repeat(reverse: true);
    setState(() {
      _readingState = _ReadingState.recording;
      _recordingElapsed = Duration.zero;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingElapsed += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _stopAndAssessReading(Question q) async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _pulseCtrl.stop();
    setState(() => _readingState = _ReadingState.processing);

    File? audioFile;
    try {
      audioFile = await _voice.stopRecording();
      if (audioFile == null) throw Exception(AppStrings.readingUploadError);

      final result = await _readingSvc.transcribeReading(
        audioFile: audioFile,
        lessonId: widget.lessonId,
        questionId: q.id,
        studentId: _activeStudentId,
      );
      if (!mounted) return;
      setState(() {
        _readingResult = result;
        _readingState = _ReadingState.result;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _readingState = _ReadingState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _readingState = _ReadingState.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      try {
        await audioFile?.delete();
      } catch (_) {}
    }
  }

  void _resetReading() {
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    _recordingTimer?.cancel();
    _recordingTimer = null;
    setState(() {
      _readingState = _ReadingState.idle;
      _readingResult = null;
      _recordingElapsed = Duration.zero;
    });
  }

  String get _recordingTimerLabel {
    final mm = _recordingElapsed.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final ss = _recordingElapsed.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return AppStrings.readingTimer(mm, ss);
  }

  void _advance() {
    debugPrint(
      '[QuestionScreen] _advance() — _index=$_index total=${_questions.length}',
    );
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    if (_index < _questions.length - 1) {
      setState(() {
        _index++;
        _selectedAnswer = null;
        _writeController.clear();
        _tracingCompleted = false;
        _rendererLocked = false;
        _hintLevel = 0;
        _remainingHints = 99;
        _loadingHint = false;
        _readingState = _ReadingState.idle;
        _readingResult = null;
        _recordingElapsed = Duration.zero;
        _dragDropTokenStatus = null;
      });
    } else {
      debugPrint(
        '[QuestionScreen] _advance() → last question reached, calling _completeAndShowQuizDialog',
      );
      _completeAndShowQuizDialog();
    }
  }

  Future<void> _onTracingGameFinished(int index) async {
    if (_tracingCompleted) return;
    _tracingCompleted = true;
    final q = _questions[_index];
    debugPrint('[QuestionScreen] tracing game finished — q.id=${q.id}');
    try {
      await QuestionService.instance.saveAnswer(
        questionId: q.id,
        lessonId: int.parse(widget.lessonId),
        answer: 'TRACED',
        questionType: 'TRACING',
        studentId: _activeStudentId,
      );
    } catch (_) {}
    if (mounted) _advance();
  }

  // ── Hint flow ─────────────────────────────────────────────

  Future<void> _fetchHint(Question q) async {
    if (_loadingHint) return;
    setState(() => _loadingHint = true);
    final nextLevel = _hintLevel + 1;
    try {
      final hint = await QuestionService.instance.getHint(
        q.id,
        level: nextLevel,
      );
      if (!mounted) return;
      setState(() {
        _hintLevel = hint.level;
        _remainingHints = hint.remainingHints;
      });
      _showHintSheet(hint, q);
    } catch (e) {
      debugPrint('[QuestionScreen] _fetchHint error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.hintFailed)));
      }
    } finally {
      if (mounted) setState(() => _loadingHint = false);
    }
  }

  void _showHintSheet(HintModel hint, Question q) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _HintBottomSheet(
        hint: hint,
        avatarEmoji: _avatarEmoji,
        avatarId: _avatarId,
        onNextLevel: hint.remainingHints > 0
            ? () {
                Navigator.pop(context);
                _fetchHint(q);
              }
            : null,
      ),
    );
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

    // Show avatar companion with context-appropriate message.
    // Auto-hides in sync with the SnackBar (950 ms later _advance() clears it).
    if (mounted) {
      setState(() {
        _feedbackMsg = correct
            ? AvatarMessages.correct(_avatarId)
            : AvatarMessages.incorrect(_avatarId);
        _showFeedbackCompanion = true;
      });
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _showFeedbackCompanion = false);
      });
    }
  }

  // ── Reading question — body & bottom area builders ────────────────────────

  Widget _buildReadingBody(Question q, String readingText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Question image — shown above reading text when available ──────
        if (q.imageUrl != null && q.imageUrl!.trim().isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              '$kBaseUrl${q.imageUrl!}',
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_rounded,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text(
          q.questionText,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.4,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),

        // Listen First button — only shown before the child starts recording
        if (_readingState == _ReadingState.idle) ...[
          Center(
            child: GestureDetector(
              onTap: () => _voice.speak(readingText, type: 'pronunciation'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'استمع أولاً 🔊',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Reading word/text card — always visible across all states
        Opacity(
          opacity: _readingState == _ReadingState.processing ? 0.45 : 1.0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
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
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),

        if (_readingState == _ReadingState.recording) ...[
          const SizedBox(height: 32),
          Center(
            child: ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.danger, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.30),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: AppColors.danger,
                  size: 40,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              _recordingTimerLabel,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.danger,
                fontFamily: 'Nunito',
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'يتم التسجيل...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],

        if (_readingState == _ReadingState.processing) ...[
          const SizedBox(height: 40),
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              AppStrings.readingProcessing,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],

        if (_readingState == _ReadingState.result &&
            _readingResult != null) ...[
          const SizedBox(height: 28),
          Center(
            child: AccuracyIndicatorWidget(
              accuracy: _readingResult!.pronunciationScore,
            ),
          ),
          const SizedBox(height: 16),
          _ReadingScoreCard(result: _readingResult!),
          const SizedBox(height: 20),
          ReadingResultWidget(result: _readingResult!),
        ],
      ],
    );
  }

  // ── Story question — body & bottom area builders ──────────────────────────

  Widget _buildStoryBody(Question q, String storyText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Title
        Text(
          q.questionText,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),

        // 2. Speaker button
        Center(
          child: GestureDetector(
            onTap: () => _voice.speak(storyText, type: 'story'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'استمع للقصة 🔊',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 3. Image
        if (q.imageUrl != null && q.imageUrl!.trim().isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.network(
              '$kBaseUrl${q.imageUrl!}',
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF5EDD8), Color(0xFFEDE0C4)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: const Text('📖', style: TextStyle(fontSize: 72)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ] else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF5EDD8), Color(0xFFEDE0C4)],
                ),
              ),
              alignment: Alignment.center,
              child: const Text('📖', style: TextStyle(fontSize: 72)),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // 4. Story text card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Text(
            storyText,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.85,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoryBottomArea() {
    final isLast = _index == _questions.length - 1;
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
      child: FatButton(
        label: isLast ? AppStrings.finish : AppStrings.continueBtn,
        onPressed: _advance,
      ),
    );
  }

  Widget _buildReadingBottomArea(Question q) {
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
      child: switch (_readingState) {
        _ReadingState.idle => FatButton(
          label: AppStrings.readingStart,
          onPressed: _startReadingRecording,
        ),
        _ReadingState.recording => FatButton(
          label: AppStrings.readingStop,
          color: FatColor.danger,
          onPressed: () => _stopAndAssessReading(q),
        ),
        _ReadingState.processing => FatButton(
          label: AppStrings.readingProcessing,
          loading: true,
          onPressed: null,
        ),
        _ReadingState.result => Row(
          children: [
            Expanded(
              child: FatButton(
                label: AppStrings.readingTryAgain,
                color: FatColor.secondary,
                onPressed: _resetReading,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FatButton(
                label: AppStrings.continueBtn,
                onPressed: _advance,
              ),
            ),
          ],
        ),
      },
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

    print('LETTERS = ${q.letters}');
    print('WORDS = ${q.words}');
    print('CORRECT ANSWERS = ${q.correctAnswers}');
    print('LETTERS COUNT = ${q.letters.length}');
    print('WORDS COUNT = ${q.words.length}');

    print('OPTIONS COUNT = ${q.options.length}');

    print('TOKENS = ${q.tokens}');
    print('TARGETS = ${q.targets}');
    print('TOKENS COUNT = ${q.tokens.length}');
    print('TARGETS COUNT = ${q.targets.length}');

    print('LEFT PAIRS COUNT = ${q.leftPairs.length}');
    print('RIGHT PAIRS COUNT = ${q.rightPairs.length}');
    print('COLORING OBJECTS COUNT = ${q.coloringObjects.length}');

    final imageOnly = _allImageOnly(q.options);
    final progress = (_index + 1) / _questions.length;

    // ── STORY ──────────────────────────────────────────────────────────────
    if (q.type == QuestionType.story) {
      final storyText = (q.expectedText?.trim().isNotEmpty == true)
          ? q.expectedText!
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
                  child: _buildStoryBody(q, storyText),
                ),
              ),
              _buildStoryBottomArea(),
            ],
          ),
        ),
      );
    }

    // ── READING ────────────────────────────────────────────────────────────
    if (q.type == QuestionType.reading) {
      final readingText = (q.expectedText?.trim().isNotEmpty == true)
          ? q.expectedText!
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
                  child: _buildReadingBody(q, readingText),
                ),
              ),
              _buildReadingBottomArea(q),
            ],
          ),
        ),
      );
    }

    // ── DRAG_DROP — rendered directly so tokenStatus + onInteraction can be
    //               passed without touching QuestionRenderer ─────────────────
    if (q.type == QuestionType.dragDrop) {
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

              if (_showFeedbackCompanion && _feedbackMsg != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: AvatarCompanion(
                    avatarEmoji: _avatarEmoji,
                    message: _feedbackMsg!,
                    compact: true,
                  ),
                ),

              Expanded(
                child: DragDropQuestion(
                  key: ValueKey('dragdrop_${q.id}'),
                  question: q,
                  onAnswer: (a) => _handleRendererAnswer(q, a),
                  locked: _rendererLocked,
                  tokenStatus: _dragDropTokenStatus,
                  onInteraction: () {
                    if (_dragDropTokenStatus != null) {
                      setState(() => _dragDropTokenStatus = null);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── MATCHING / COLORING — rendered via QuestionRenderer ────────────────
    if (q.type == QuestionType.matching ||
        q.type == QuestionType.coloring ||
        q.type == QuestionType.letterCompletion) {
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

              // Avatar companion feedback — shown above the renderer
              if (_showFeedbackCompanion && _feedbackMsg != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: AvatarCompanion(
                    avatarEmoji: _avatarEmoji,
                    message: _feedbackMsg!,
                    compact: true,
                  ),
                ),

              Expanded(
                child: QuestionRenderer(
                  question: q,
                  onAnswer: (a) => _handleRendererAnswer(q, a),
                  locked: _rendererLocked,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Generic branch: MCQ, TRUE_FALSE, WRITE_ANSWER, SHORT_ANSWER,
    //                    FILL_BLANK, TRACING, and any unknown types ──────────
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
                    // Question text + read-aloud button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            q.questionText,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TtsSpeakerButton(
                          text: q.questionText,
                          audioType: 'explanation',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Hint pill — shown for all question types in this branch
                    Align(
                      alignment: Alignment.centerRight,
                      child: _HintPill(
                        loading: _loadingHint,
                        disabled: _hintLevel > 0 && _remainingHints <= 0,
                        onPressed: () => _fetchHint(q),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Context image (shown above options when question has one)
                    if (q.imageUrl != null &&
                        q.imageUrl!.trim().isNotEmpty &&
                        q.type != QuestionType.tracing) ...[
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
                    if (q.type == QuestionType.writeAnswer ||
                        q.type == QuestionType.voiceAnswer ||
                        q.type == QuestionType.fillBlank)
                      _WriteField(
                        controller: _writeController,
                        onChanged: (v) => setState(() => _selectedAnswer = v),
                      ),

                    // ── Tracing canvas ──────────────────────────────
                    if (q.type == QuestionType.tracing)
                      _TracingArea(
                        key: ValueKey('tracing_$_index'),
                        questionText: q.questionText,
                        onGameFinished: _onTracingGameFinished,
                      ),
                  ],
                ),
              ),
            ),

            // ── Avatar companion — correct / incorrect feedback ───────
            if (_showFeedbackCompanion && _feedbackMsg != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: AvatarCompanion(
                  avatarEmoji: _avatarEmoji,
                  message: _feedbackMsg!,
                  compact: true,
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
// TRACING AREA — new game widget wrapped in a styled container
// ═════════════════════════════════════════════════════════════════════════════

class _TracingArea extends StatelessWidget {
  const _TracingArea({
    super.key,
    required this.questionText,
    required this.onGameFinished,
  });

  final String questionText;
  final Future<void> Function(int index) onGameFinished;

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
        child: TracingHelper.buildGameWidget(
          text: questionText,
          onGameFinished: onGameFinished,
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

// ═════════════════════════════════════════════════════════════════════════════
// HINT PILL — small chip button shown below the question text
// ═════════════════════════════════════════════════════════════════════════════

class _HintPill extends StatelessWidget {
  const _HintPill({
    required this.loading,
    required this.disabled,
    required this.onPressed,
  });

  final bool loading;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = !loading && !disabled;
    return GestureDetector(
      onTap: active ? onPressed : null,
      child: Container(
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
              disabled ? AppStrings.hintNoMore : AppStrings.hintButton,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: disabled ? AppColors.textSecondary : AppColors.flame,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HINT BOTTOM SHEET — displays the hint text and optional next-level button
// ═════════════════════════════════════════════════════════════════════════════

class _HintBottomSheet extends StatelessWidget {
  const _HintBottomSheet({
    required this.hint,
    required this.avatarEmoji,
    this.avatarId,
    this.onNextLevel,
  });

  final HintModel hint;
  final String avatarEmoji;
  final String? avatarId;
  final VoidCallback? onNextLevel;

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 16),

            // Avatar companion introduces the hint
            AvatarCompanion(
              avatarEmoji: avatarEmoji,
              message: AvatarMessages.hint(avatarId),
              compact: true,
              audioType: 'hint',
            ),
            const SizedBox(height: 16),

            // Header: lightbulb icon + title + level badge
            Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Text(
                  AppStrings.hintSheetTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppStrings.hintLevelLabel(hint.level),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.flame,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Hint text card — matches the warm card style used across the app
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    hint.hint,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.6,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TtsSpeakerButton(text: hint.hint, audioType: 'hint'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Remaining hints indicator
            if (hint.remainingHints > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppStrings.hintRemainingLabel(hint.remainingHints),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...List.generate(
                      hint.remainingHints.clamp(0, 5),
                      (_) => const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Icons.circle,
                          size: 8,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  AppStrings.hintNoMore,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

            // "Stronger hint" button — only shown when the backend says more are available
            if (onNextLevel != null) ...[
              FatButton(
                label: AppStrings.hintNextLevel,
                color: FatColor.gold,
                onPressed: onNextLevel,
              ),
              const SizedBox(height: 10),
            ],

            // Close button
            FatButton(
              label: AppStrings.hintClose,
              color: FatColor.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// READING SCORE CARD — pronunciation score + feedback label (reading questions)
// ═════════════════════════════════════════════════════════════════════════════

class _ReadingScoreCard extends StatelessWidget {
  const _ReadingScoreCard({required this.result});
  final ReadingAssessmentResult result;

  Color get _color {
    final s = result.pronunciationScore;
    if (s >= 90) return const Color(0xFF2E7D32);
    if (s >= 70) return const Color(0xFF1565C0);
    if (s >= 50) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  Color get _bgColor {
    final s = result.pronunciationScore;
    if (s >= 90) return const Color(0xFFE8F5E9);
    if (s >= 70) return const Color(0xFFE3F2FD);
    if (s >= 50) return const Color(0xFFFFF3E0);
    return const Color(0xFFFFEBEE);
  }

  @override
  Widget build(BuildContext context) {
    if (result.feedback.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _color.withValues(alpha: 0.30), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'نتيجة النطق: ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
          Text(
            '${result.pronunciationScore}%',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _color,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              result.feedback,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
