// ════════════════════════════════════════════════════════════════════════════
// fill_blank_question — sentence with "___" placeholder.
// Tap a word chip from the bank → it fills the blank.
// Tap the filled word → returns it to the bank.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../../../theme/theme.dart';
import '../fat_button.dart';
import '../quiz/question_callback.dart';
import '../quiz/shared/question_header.dart';

class FillBlankQuestion extends StatefulWidget {
  const FillBlankQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<FillBlankQuestion> createState() => _FillBlankQuestionState();
}

class _FillBlankQuestionState extends State<FillBlankQuestion> {
  String? _filled;

  void _select(String word) {
    if (widget.locked) return;
    setState(() => _filled = word);
  }

  void _clear() {
    if (widget.locked) return;
    setState(() => _filled = null);
  }

  void _submit() {
    if (_filled == null) return;
    final assembled = widget.question.questionText.replaceFirst(
      _blankPattern,
      _filled!,
    );
    widget.onAnswer(SubmittedAnswer(answer: assembled));
  }

  static final RegExp _blankPattern = RegExp(
    r'_{2,}|\{blank\}',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final parts = q.questionText.split(_blankPattern);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestionHeader(prompt: 'Fill in the blank', audioUrl: q.audioUrl),
          const SizedBox(height: 24),

          // Sentence with the blank
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 8,
            children: [
              if (parts.isNotEmpty) _textSpan(parts.first),
              _blankSlot(),
              if (parts.length > 1) _textSpan(parts.last),
            ],
          ),

          const SizedBox(height: 32),
          const Text(
            'Word bank',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // Word chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: q.wordBank.map((w) {
              final used = w == _filled;
              return Opacity(
                opacity: used ? 0.35 : 1,
                child: GestureDetector(
                  onTap: used ? null : () => _select(w),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE5E5E5),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFFE5E5E5),
                          offset: Offset(0, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),
          FatButton(
            label: 'Check answer',
            onPressed: (_filled == null || widget.locked) ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _textSpan(String s) => Text(
    s,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  );

  Widget _blankSlot() {
    return GestureDetector(
      onTap: _filled == null ? null : _clear,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        constraints: const BoxConstraints(minWidth: 80),
        decoration: BoxDecoration(
          color: _filled == null ? Colors.white : const Color(0xFFE6F6FE),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _filled == null
                ? const Color(0xFFCFCFCF)
                : AppColors.secondary,
            width: 2,
            style: _filled == null ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Text(
          _filled ?? '   ',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: _filled == null
                ? AppColors.textSecondary
                : AppColors.secondary,
          ),
        ),
      ),
    );
  }
}
