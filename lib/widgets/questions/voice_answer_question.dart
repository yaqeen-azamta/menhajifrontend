// ════════════════════════════════════════════════════════════════════════════
// voice_answer_question — student records their voice; transcription
// is sent as the answer. Re-uses the existing MicButton + VoiceService.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../../../theme/theme.dart';
import '../fat_button.dart';
import '../mic_button.dart';
import '../quiz/question_callback.dart';
import '../quiz/shared/question_card.dart';
import '../quiz/shared/question_header.dart';

class VoiceAnswerQuestion extends StatefulWidget {
  const VoiceAnswerQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<VoiceAnswerQuestion> createState() => _VoiceAnswerQuestionState();
}

class _VoiceAnswerQuestionState extends State<VoiceAnswerQuestion> {
  String? _transcript;

  void _onTranscript(String t) {
    if (t.isEmpty || t == '__no_permission__') {
      setState(() => _transcript = t);
      return;
    }
    setState(() => _transcript = t);
  }

  void _submit() {
    if (_transcript == null || _transcript == '__no_permission__') return;
    widget.onAnswer(
      SubmittedAnswer(answer: _transcript!, spokenText: _transcript!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final hasText = _transcript != null && _transcript != '__no_permission__';
    final denied = _transcript == '__no_permission__';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          QuestionHeader(prompt: q.questionText, audioUrl: q.audioUrl),
          const SizedBox(height: 24),

          // Hint card for what to say
          if (q.expectedText != null && q.expectedText!.isNotEmpty)
            QuestionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SAY THIS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    q.expectedText!,
                    textDirection: _hasArabic(q.expectedText!)
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 28),
          MicButton(onTranscript: _onTranscript),

          if (hasText) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2FFE8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFE89E), width: 1),
              ),
              child: Text(
                'You said: "$_transcript"',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 20),
            FatButton(
              label: 'Submit',
              onPressed: widget.locked ? null : _submit,
            ),
          ],

          if (denied)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Mic permission needed to use voice answers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.flame,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _hasArabic(String s) => RegExp(r'[\u0600-\u06FF]').hasMatch(s);
}
