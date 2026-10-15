// ════════════════════════════════════════════════════════════════════════════
// letter_completion_question.dart
//
// LETTER_COMPLETION — letter bank + words with blanks.
// Tap a letter chip to select it, then tap a blank to fill it.
// Tap a filled blank to clear it.
// All blanks must be filled before "Check answer" is enabled.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../../../theme/theme.dart';
import '../fat_button.dart';
import '../quiz/question_callback.dart';
import '../quiz/shared/question_header.dart';

class LetterCompletionQuestion extends StatefulWidget {
  const LetterCompletionQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<LetterCompletionQuestion> createState() =>
      _LetterCompletionQuestionState();
}

class _LetterCompletionQuestionState
    extends State<LetterCompletionQuestion> {
  String? _selectedLetter;
  late final List<String?> _answers;

  @override
  void initState() {
    super.initState();
    _answers = List<String?>.filled(
      widget.question.words.length,
      null,
      growable: false,
    );
  }

  bool get _allFilled => _answers.every((a) => a != null && a.isNotEmpty);

  void _toggleLetter(String letter) {
    if (widget.locked) return;
    setState(
      () => _selectedLetter = (_selectedLetter == letter) ? null : letter,
    );
  }

  void _tapBlank(int index) {
    if (widget.locked) return;
    setState(() {
      if (_selectedLetter != null) {
        _answers[index] = _selectedLetter;
        // Keep letter selected — same letter can fill multiple blanks.
      } else {
        _answers[index] = null;
      }
    });
  }

  void _submit() {
    if (!_allFilled) return;
    final parts = _answers.whereType<String>().toList();
    widget.onAnswer(
      SubmittedAnswer(
        answer: parts.join(','),
        structured: {'answers': parts},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestionHeader(
            prompt: q.questionText.isNotEmpty
                ? q.questionText
                : 'اختر الحرف المناسب لكل كلمة',
            audioUrl: q.audioUrl,
          ),
          const SizedBox(height: 28),

          // ── Letter bank ──────────────────────────────────────────────────
          _SectionLabel(label: 'الحروف المتاحة'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: q.letters.map((letter) {
              final isSelected = letter == _selectedLetter;
              return _LetterChip(
                letter: letter,
                isSelected: isSelected,
                locked: widget.locked,
                onTap: () => _toggleLetter(letter),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // ── Words list ───────────────────────────────────────────────────
          _SectionLabel(label: 'أكمل الكلمات'),
          const SizedBox(height: 14),
          ...List.generate(q.words.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _WordRow(
                index: i,
                word: q.words[i],
                filled: _answers[i],
                hasSelection: _selectedLetter != null,
                locked: widget.locked,
                onTapBlank: () => _tapBlank(i),
              ),
            );
          }),

          const SizedBox(height: 8),
          FatButton(
            label: 'تحقق من الإجابة',
            onPressed: (_allFilled && !widget.locked) ? _submit : null,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _SectionLabel
// ════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textDirection: TextDirection.rtl,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: AppColors.textSecondary,
        letterSpacing: 0.6,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _LetterChip — tappable letter from the bank
// ════════════════════════════════════════════════════════════════════════════

class _LetterChip extends StatelessWidget {
  const _LetterChip({
    required this.letter,
    required this.isSelected,
    required this.locked,
    required this.onTap,
  });

  final String letter;
  final bool isSelected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.secondary
                : const Color(0xFFDDDDDD),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.secondary.withValues(alpha: 0.22)
                  : const Color(0xFFE0E0E0),
              offset: const Offset(0, 4),
              blurRadius: isSelected ? 10 : 0,
            ),
          ],
        ),
        child: Text(
          letter,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: isSelected ? AppColors.secondary : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _WordRow — one word card with an inline blank slot
// ════════════════════════════════════════════════════════════════════════════

class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.index,
    required this.word,
    required this.filled,
    required this.hasSelection,
    required this.locked,
    required this.onTapBlank,
  });

  final int index;
  final String word;
  final String? filled;
  final bool hasSelection;
  final bool locked;
  final VoidCallback onTapBlank;

  static const _blank = '__';

  @override
  Widget build(BuildContext context) {
    final parts = word.split(_blank);
    final prefix = parts.isNotEmpty ? parts[0] : '';
    final suffix = parts.length > 1 ? parts[1] : '';
    final hasFilled = filled != null && filled!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasFilled
              ? AppColors.secondary.withValues(alpha: 0.45)
              : const Color(0xFFE8E8E8),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFEEEEEE),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row index badge (shown LTR — stays on visual right in RTL row)
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Word with blank inline
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 2,
                children: [
                  if (prefix.isNotEmpty)
                    Text(
                      prefix,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                  _BlankSlot(
                    filled: filled,
                    isActive: hasSelection && !locked,
                    locked: locked,
                    onTap: onTapBlank,
                  ),
                  if (suffix.isNotEmpty)
                    Text(
                      suffix,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _BlankSlot — the tappable drop zone embedded in each word
// ════════════════════════════════════════════════════════════════════════════

class _BlankSlot extends StatelessWidget {
  const _BlankSlot({
    required this.filled,
    required this.isActive,
    required this.locked,
    required this.onTap,
  });

  final String? filled;
  final bool isActive;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasFilled = filled != null && filled!.isNotEmpty;

    return GestureDetector(
      onTap: locked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 52,
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hasFilled
              ? AppColors.secondary.withValues(alpha: 0.12)
              : isActive
                  ? const Color(0xFFFFFDE7)
                  : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFilled
                ? AppColors.secondary
                : isActive
                    ? const Color(0xFFFFC107)
                    : const Color(0xFFCFCFCF),
            width: (hasFilled || isActive) ? 2.5 : 1.5,
          ),
          boxShadow: hasFilled
              ? [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    offset: const Offset(0, 3),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: hasFilled
            ? Text(
                filled!,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.secondary,
                ),
              )
            : Icon(
                Icons.add_rounded,
                size: 22,
                color: isActive
                    ? const Color(0xFFFFC107)
                    : const Color(0xFFBBBBBB),
              ),
      ),
    );
  }
}
