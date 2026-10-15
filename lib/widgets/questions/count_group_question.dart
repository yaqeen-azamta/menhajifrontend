// ════════════════════════════════════════════════════════════════════════════
// count_group_question.dart
//
// COUNT_GROUP — student sees 2‑4 image cards each showing a different group
// of objects. They tap the card whose group matches the question prompt
// ("Choose the group with 1 object"). Auto-submits on selection.
//
// Answer contract: SubmittedAnswer.answer = selected option text (same as MCQ).
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../../../theme/theme.dart';
import '../quiz/question_callback.dart';
import '../quiz/shared/question_header.dart';

class CountGroupQuestion extends StatefulWidget {
  const CountGroupQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<CountGroupQuestion> createState() => _CountGroupQuestionState();
}

class _CountGroupQuestionState extends State<CountGroupQuestion> {
  int? _selected;

  void _select(int index) {
    if (widget.locked) return;
    setState(() => _selected = index);
    final optionText = widget.question.options[index].text;
    widget.onAnswer(SubmittedAnswer(answer: optionText));
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final opts = q.options;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestionHeader(prompt: q.questionText, audioUrl: q.audioUrl),
          const SizedBox(height: 28),
          _buildGrid(opts),
        ],
      ),
    );
  }

  Widget _buildGrid(List<QuestionOption> opts) {
    // Use a 2-column grid — child-friendly, large tappable cards.
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: opts.length,
      itemBuilder: (context, i) => _GroupCard(
        option: opts[i],
        isSelected: _selected == i,
        locked: widget.locked,
        onTap: () => _select(i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual group card
// ─────────────────────────────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.option,
    required this.isSelected,
    required this.locked,
    required this.onTap,
  });

  final QuestionOption option;
  final bool isSelected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = option.imageUrl.isNotEmpty;
    final hasText  = option.text.isNotEmpty;

    final borderColor = isSelected ? AppColors.primary : const Color(0xFFE0E0E0);
    final bgColor     = isSelected
        ? AppColors.primary.withValues(alpha: 0.10)
        : Colors.white;

    return GestureDetector(
      onTap: locked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Main content ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasImage)
                    Expanded(
                      child: Image.network(
                        option.imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                        errorBuilder: (ctx, err, stack) => const Icon(
                          Icons.image_not_supported_outlined,
                          size: 48,
                          color: Color(0xFFCCCCCC),
                        ),
                      ),
                    ),
                  if (hasText) ...[
                    if (hasImage) const SizedBox(height: 8),
                    Text(
                      option.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Selected checkmark ────────────────────────────────
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
