import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_strings.dart';
import '../services/api_client.dart';
import '../services/reading_service.dart';
import '../services/voice_service.dart';
import '../theme/theme.dart';
import '../widgets/fat_button.dart';
import '../widgets/reading/accuracy_indicator_widget.dart';
import '../widgets/reading/reading_result_widget.dart';

// ─────────────────────────────────────────────────────────────
// Screen state machine
// ─────────────────────────────────────────────────────────────

enum _ScreenState {
  loadingText, // fetching paragraph from backend
  ready, // paragraph loaded — waiting for student to start
  recording, // microphone active
  processing, // audio uploaded — awaiting assessment response
  result, // assessment result on screen
  textError, // failed to fetch paragraph
  assessmentError, // failed to assess recording
}

// ─────────────────────────────────────────────────────────────
// ReadingScreen
// ─────────────────────────────────────────────────────────────

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({
    super.key,
    required this.lessonId,
    required this.questionId,
    this.readingText,
    this.onComplete,
  });

  final String lessonId;
  final int questionId;

  /// When provided, the screen skips the GET /api/reading/lesson/{id} call
  /// and uses this text directly — the source of truth is the question record.
  final String? readingText;

  /// Called when the user explicitly taps "Continue" on the result screen.
  /// QuestionScreen uses this to gate _advance() so the lesson only progresses
  /// on deliberate user action, not on any incidental dismissal of the screen.
  final VoidCallback? onComplete;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen>
    with SingleTickerProviderStateMixin {
  // ── Service singletons (follow existing project pattern) ──
  final _reading = ReadingService.instance;
  final _voice = VoiceService.instance;

  // ── Screen state ──────────────────────────────────────────
  _ScreenState _state = _ScreenState.loadingText;
  String? _errorMessage;

  // ── Paragraph data ────────────────────────────────────────
  String _readingText = '';
  String _lessonTitle = '';

  // ── Assessment result ─────────────────────────────────────
  ReadingAssessmentResult? _result;

  // ── Recording timer ───────────────────────────────────────
  Timer? _recordingTimer;
  Duration _elapsed = Duration.zero;

  // ── Pulse animation for recording indicator ───────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    debugPrint('[ReadingScreen] initState — lessonId=${widget.lessonId} questionId=${widget.questionId} readingText="${widget.readingText}"');
    // Pulse animation is created here but NOT started.
    // It only starts when _startRecording() is explicitly called by the user.
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.22,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadText();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────

  Future<void> _loadText() async {
    // Fast path: text was forwarded directly from the question record.
    // No network call needed — satisfies "source of truth is the question".
    final injected = widget.readingText?.trim() ?? '';
    if (injected.isNotEmpty) {
      debugPrint('[ReadingScreen] → ready state (text="${injected.length > 30 ? injected.substring(0, 30) : injected}…")');
      setState(() {
        _readingText = injected;
        _lessonTitle = AppStrings.readingTitle;
        _state = _ScreenState.ready;
      });
      return;
    }

    // Fallback: fetch from the reading endpoint (legacy / standalone path).
    setState(() {
      _state = _ScreenState.loadingText;
      _errorMessage = null;
    });
    try {
      final model = await _reading.fetchReadingText(widget.lessonId);
      if (model.text.isEmpty) throw Exception(AppStrings.readingNoText);
      setState(() {
        _readingText = model.text;
        _lessonTitle = model.title;
        _state = _ScreenState.ready;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _state = _ScreenState.textError;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _state = _ScreenState.textError;
      });
    }
  }

  // ── Recording controls ────────────────────────────────────

  Future<void> _startRecording() async {
    // Guard: only transition from ready state. Prevents double-tap or race conditions.
    if (_state != _ScreenState.ready) return;

    final granted = await _voice.startRecording();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.readingPermissionDenied),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }
    debugPrint('[ReadingScreen] user pressed Start → entering recording state');
    _pulseCtrl.repeat(reverse: true);
    setState(() {
      _state = _ScreenState.recording;
      _elapsed = Duration.zero;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stopAndSubmit() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    debugPrint('[ReadingScreen] → processing state');
    setState(() => _state = _ScreenState.processing);

    File? audioFile;
    try {
      audioFile = await _voice.stopRecording();
      if (audioFile == null) throw Exception(AppStrings.readingUploadError);

      final result = await _reading.transcribeReading(
        audioFile: audioFile,
        lessonId: widget.lessonId,
        questionId: widget.questionId,
      );

      debugPrint('[ReadingScreen] → result state (score=${result.pronunciationScore} feedback="${result.feedback}")');
      setState(() {
        _result = result;
        _state = _ScreenState.result;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _state = _ScreenState.assessmentError;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _state = _ScreenState.assessmentError;
      });
    } finally {
      // Always clean up the temp audio file.
      try {
        await audioFile?.delete();
      } catch (_) {}
    }
  }

  void _tryAgain() {
    _pulseCtrl.stop();
    _pulseCtrl.reset();
    setState(() {
      _result = null;
      _elapsed = Duration.zero;
      _errorMessage = null;
      _state = _ScreenState.ready;
    });
    debugPrint('[ReadingScreen] → ready state (try again)');
  }

  // ── Timer formatting ──────────────────────────────────────

  String get _timerLabel {
    final mm = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return AppStrings.readingTimer(mm, ss);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              title: _lessonTitle.isNotEmpty
                  ? _lessonTitle
                  : AppStrings.readingTitle,
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ScreenState.loadingText:
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );

      case _ScreenState.textError:
        return _ErrorView(
          message: _errorMessage ?? AppStrings.readingLoadError,
          onRetry: _loadText,
        );

      case _ScreenState.ready:
        return _ReadyView(text: _readingText);

      case _ScreenState.recording:
        return _RecordingView(
          text: _readingText,
          timerLabel: _timerLabel,
          pulseAnim: _pulseAnim,
        );

      case _ScreenState.processing:
        return _ProcessingView(text: _readingText);

      case _ScreenState.result:
        debugPrint('[ReadingScreen] _buildBody → drawing result UI (score=${_result?.pronunciationScore})');
        return _ResultView(result: _result!);

      case _ScreenState.assessmentError:
        return _ErrorView(
          message: _errorMessage ?? AppStrings.readingUploadError,
          onRetry: _tryAgain,
        );
    }
  }

  Widget? _buildBottomBar() {
    switch (_state) {
      case _ScreenState.ready:
        return _BottomBar(
          child: FatButton(
            label: AppStrings.readingStart,
            onPressed: _startRecording,
          ),
        );

      case _ScreenState.recording:
        return _BottomBar(
          child: FatButton(
            label: AppStrings.readingStop,
            color: FatColor.danger,
            onPressed: _stopAndSubmit,
          ),
        );

      case _ScreenState.result:
        debugPrint('[ReadingScreen] _buildBottomBar → result state, rendering Continue + TryAgain buttons');
        return _BottomBar(
          child: Row(
            children: [
              Expanded(
                child: FatButton(
                  label: AppStrings.readingTryAgain,
                  color: FatColor.secondary,
                  onPressed: _tryAgain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FatButton(
                  label: AppStrings.continueBtn,
                  onPressed: () {
                    debugPrint('[ReadingScreen] ✅ Continue button PRESSED by user');
                    debugPrint('[ReadingScreen] calling onComplete callback — onComplete is ${widget.onComplete == null ? "NULL" : "set"}');
                    widget.onComplete?.call();
                    debugPrint('[ReadingScreen] onComplete called, now popping');
                    context.canPop() ? context.pop() : context.go('/home');
                  },
                ),
              ),
            ],
          ),
        );

      default:
        return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-views
// ─────────────────────────────────────────────────────────────

/// Displays the paragraph and waits for the student to tap "Start".
class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            AppStrings.readingInstruction,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _ParagraphCard(text: text),
        ],
      ),
    );
  }
}

/// Shows the paragraph + a pulsing mic badge + elapsed timer.
class _RecordingView extends StatelessWidget {
  const _RecordingView({
    required this.text,
    required this.timerLabel,
    required this.pulseAnim,
  });

  final String text;
  final String timerLabel;
  final Animation<double> pulseAnim;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        children: [
          _ParagraphCard(text: text),
          const SizedBox(height: 28),
          // Pulsing mic indicator
          ScaleTransition(
            scale: pulseAnim,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.danger, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.30),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: AppColors.danger,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Elapsed timer
          Text(
            timerLabel,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.danger,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'يتم التسجيل...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the paragraph dimmed while the backend analyses the audio.
class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        children: [
          Opacity(opacity: 0.45, child: _ParagraphCard(text: text)),
          const SizedBox(height: 36),
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            AppStrings.readingProcessing,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full result view — accuracy arc + pronunciation score card + word breakdown.
class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});
  final ReadingAssessmentResult result;

  @override
  Widget build(BuildContext context) {
    debugPrint('[RESULT BUILD] result widget built');
    debugPrint('[RESULT BUILD] score=${result.accuracy} feedback="${result.feedback}" originalText="${result.originalText}" recognizedText="${result.recognizedText}"');
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        AccuracyIndicatorWidget(accuracy: result.pronunciationScore),
        const SizedBox(height: 16),
        _PronunciationScoreCard(result: result),
        const SizedBox(height: 24),
        ReadingResultWidget(result: result),
      ],
    );
  }
}

/// Shows the exact pronunciation score + Arabic feedback label from the backend.
class _PronunciationScoreCard extends StatelessWidget {
  const _PronunciationScoreCard({required this.result});
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
    // Only render if the backend actually sent a feedback string.
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
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
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            FatButton(label: AppStrings.retry, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared structural widgets
// ─────────────────────────────────────────────────────────────

/// Top bar with back arrow and title — mirrors the style used in
/// RewardsScreen and other screens in the project.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left, size: 28),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// The reading paragraph displayed in a warm bordered card.
class _ParagraphCard extends StatelessWidget {
  const _ParagraphCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.9,
          color: AppColors.textPrimary,
        ),
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

/// SafeArea wrapper for the sticky bottom action button.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: child,
      ),
    );
  }
}
