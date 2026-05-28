// ════════════════════════════════════════════════════════════════════════════
// drag_drop_question — student drags tokens into named target slots.
//
// Question shape:
//   targets : ["Animal",  "Plant",  "Mineral"]
//   tokens  : ["Dog",     "Rose",   "Gold",   "Cat"]
//
// Student drags each token into the correct target. Backend receives
// "Animal=Dog,Animal=Cat,Plant=Rose,Mineral=Gold" as the answer string.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../../../theme/theme.dart';
import '../fat_button.dart';
import '../quiz/question_callback.dart';
import '../quiz/shared/question_header.dart';

class DragDropQuestion extends StatefulWidget {
  const DragDropQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<DragDropQuestion> createState() => _DragDropQuestionState();
}

class _DragDropQuestionState extends State<DragDropQuestion> {
  /// targetLabel → list of dropped tokens
  late final Map<String, List<String>> _drops = {
    for (final t in widget.question.targets) t: <String>[],
  };

  late final List<String> _bank = List.from(widget.question.tokens);

  void _drop(String token, String target) {
    if (widget.locked) return;
    setState(() {
      _bank.remove(token);
      _drops[target]!.add(token);
    });
  }

  void _returnToBank(String token, String fromTarget) {
    if (widget.locked) return;
    setState(() {
      _drops[fromTarget]!.remove(token);
      _bank.add(token);
    });
  }

  bool get _canSubmit => _bank.isEmpty;

  void _submit() {
    final pairs = <String>[];
    _drops.forEach((target, tokens) {
      for (final t in tokens) {
        pairs.add('$target=$t');
      }
    });
    widget.onAnswer(
      SubmittedAnswer(answer: pairs.join(','), structured: {'drops': _drops}),
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
          QuestionHeader(prompt: q.questionText, audioUrl: q.audioUrl),
          const SizedBox(height: 24),

          // Target zones
          ...q.targets.map((target) {
            final tokens = _drops[target] ?? [];
            return DragTarget<String>(
              onWillAcceptWithDetails: (details) => !widget.locked,
              onAcceptWithDetails: (details) => _drop(details.data, target),
              builder: (ctx, candidates, rejected) {
                final hovering = candidates.isNotEmpty;
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: hovering
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: hovering
                          ? AppColors.primary
                          : const Color(0xFFE5E5E5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        target,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (tokens.isEmpty)
                        Container(
                          height: 36,
                          alignment: Alignment.center,
                          child: const Text(
                            'Drop here',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: tokens
                              .map(
                                (t) => GestureDetector(
                                  onTap: () => _returnToBank(t, target),
                                  child: _tokenChip(
                                    t,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                );
              },
            );
          }),

          const SizedBox(height: 12),
          const Text(
            'Drag from below',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // Bank
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _bank.map((t) {
              return Draggable<String>(
                data: t,
                feedback: Material(
                  color: Colors.transparent,
                  child: _tokenChip(t, color: AppColors.secondary),
                ),
                childWhenDragging: Opacity(opacity: 0.3, child: _tokenChip(t)),
                child: _tokenChip(t),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),
          FatButton(
            label: 'Check answer',
            onPressed: (_canSubmit && !widget.locked) ? _submit : null,
          ),
        ],
      ),
    );
  }

  Widget _tokenChip(String text, {Color? color}) {
    final c = color ?? const Color(0xFFE5E5E5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color == null ? Colors.white : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c, width: 2),
        boxShadow: [
          BoxShadow(color: c, offset: const Offset(0, 3), blurRadius: 0),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
      ),
    );
  }
}
