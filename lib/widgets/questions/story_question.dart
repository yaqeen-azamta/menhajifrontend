// ════════════════════════════════════════════════════════════════════════════
// story_question.dart — Quiz widget for QuestionType.story
//
// Content-consumption only. Layout:
//   Title → Speaker button → Image → Story text → Continue button
//
// Audio: VoiceService.speak(storyText, type: 'story')
//        Falls back to audioUrl playback when provided.
//
// No hints. No answer validation. No recording. No pronunciation assessment.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../models/question_model.dart';
import '../../services/api_client.dart';
import '../../services/voice_service.dart';
import '../../theme/theme.dart';
import '../quiz/question_callback.dart';

class StoryQuestion extends StatefulWidget {
  const StoryQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<StoryQuestion> createState() => _StoryQuestionState();
}

class _StoryQuestionState extends State<StoryQuestion> {
  bool _isLoading = false;

  // Story content lives in expectedText, which Question.fromJson() maps from
  // the backend's correctAnswer field.
  String get _storyText =>
      (widget.question.expectedText?.trim().isNotEmpty == true)
          ? widget.question.expectedText!
          : widget.question.questionText;

  Future<void> _speak() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    await VoiceService.instance.speak(_storyText, type: 'story');
    if (mounted) setState(() => _isLoading = false);
  }

  void _continue() {
    if (widget.locked) return;
    widget.onAnswer(const SubmittedAnswer(answer: 'STORY'));
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final hasImage = q.imageUrl != null && q.imageUrl!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. Title ─────────────────────────────────────────────────────────
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

        // ── 2. Speaker button ─────────────────────────────────────────────────
        Center(
          child: GestureDetector(
            onTap: _speak,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  else
                    const Icon(Icons.volume_up_rounded,
                        color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    _isLoading ? 'جارٍ التحميل...' : 'استمع للقصة 🔊',
                    style: const TextStyle(
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

        // ── 3. Image ──────────────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: hasImage
              ? Image.network(
                  '$kBaseUrl${q.imageUrl!}',
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _StoryPlaceholder(),
                )
              : const _StoryPlaceholder(),
        ),
        const SizedBox(height: 20),

        // ── 4. Story text card ────────────────────────────────────────────────
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
            _storyText,
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
        const SizedBox(height: 32),

        // ── 5. Continue button ────────────────────────────────────────────────
        _ContinueButton(
          onPressed: widget.locked ? null : _continue,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Warm parchment placeholder — shown when no imageUrl is provided ───────────

class _StoryPlaceholder extends StatelessWidget {
  const _StoryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5EDD8), Color(0xFFEDE0C4)],
        ),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📖', style: TextStyle(fontSize: 72)),
          SizedBox(height: 8),
          Text(
            'قصة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Continue pill ─────────────────────────────────────────────────────────────

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary : const Color(0xFFCCCCCC),
          borderRadius: BorderRadius.circular(22),
          border: Border(
            bottom: BorderSide(
              color: enabled
                  ? AppColors.primaryShadow
                  : const Color(0xFFAAAAAA),
              width: 5,
            ),
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: const Center(
          child: Text(
            'متابعة ›',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
