// ════════════════════════════════════════════════════════════════════════════
// reorder_words — student taps words from the bank in order to build a
// sentence in the answer area. Tapping an answer word sends it back.
//
// Backend receives the assembled sentence (space-joined) as the answer.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../../../theme/theme.dart';
import '../fat_button.dart';
import '../quiz/question_callback.dart';
import '../quiz/shared/question_header.dart';

class ReorderWordsQuestion extends StatefulWidget {
  const ReorderWordsQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<ReorderWordsQuestion> createState() => _ReorderWordsQuestionState();
}

class _ReorderWordsQuestionState extends State<ReorderWordsQuestion> {
  final List<String> _answer = [];
  late final List<String> _bank = List.from(widget.question.tokens);

  bool _isRtl() => widget.question.tokens.any(_isArabic);
  bool _isArabic(String s) => RegExp(r'[\u0600-\u06FF]').hasMatch(s);

  void _addWord(int bankIdx) {
    if (widget.locked) return;
    setState(() {
      _answer.add(_bank[bankIdx]);
      _bank.removeAt(bankIdx);
    });
  }

  void _removeWord(int answerIdx) {
    if (widget.locked) return;
    setState(() {
      _bank.add(_answer[answerIdx]);
      _answer.removeAt(answerIdx);
    });
  }

  void _submit() {
    final sep = _isRtl() ? ' ' : ' ';
    widget.onAnswer(SubmittedAnswer(answer: _answer.join(sep)));
  }

  @override
  Widget build(BuildContext context) {
    final rtl = _isRtl();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestionHeader(
            prompt: widget.question.questionText.isNotEmpty
                ? widget.question.questionText
                : 'Tap the words in the correct order',
            audioUrl: widget.question.audioUrl,
          ),

          const SizedBox(height: 20),

          // Answer area (always visible — Duolingo style)
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: rtl ? WrapAlignment.end : WrapAlignment.start,
              children: _answer.asMap().entries.map((e) {
                return GestureDetector(
                  onTap: () => _removeWord(e.key),
                  child: _chip(e.value, primary: true),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE5E5E5)),
          const SizedBox(height: 16),

          // Word bank
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: rtl ? WrapAlignment.end : WrapAlignment.start,
            children: _bank.asMap().entries.map((e) {
              return GestureDetector(
                onTap: () => _addWord(e.key),
                child: _chip(e.value),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),
          FatButton(
            label: 'Check answer',
            onPressed: (_answer.isEmpty || widget.locked) ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _chip(String s, {bool primary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: primary ? AppColors.secondary.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primary ? AppColors.secondary : const Color(0xFFE5E5E5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: primary ? AppColors.secondary : const Color(0xFFE5E5E5),
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        s,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          color: primary ? AppColors.secondary : AppColors.textPrimary,
        ),
      ),
    );
  }
}
