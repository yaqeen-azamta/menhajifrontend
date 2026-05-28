// ════════════════════════════════════════════════════════════════════════════
// MCQ question — large tappable options, single selection.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../quiz/question_callback.dart';
import '../quiz/shared/question_header.dart';

class McqQuestion extends StatefulWidget {
  const McqQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<McqQuestion> createState() => _McqQuestionState();
}

class _McqQuestionState extends State<McqQuestion> {
  int? _selected;

  void _select(int i) {
    setState(() => _selected = i);
    // Auto-submit on select — like Duolingo
    widget.onAnswer(SubmittedAnswer(answer: widget.question.options[i].text));
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestionHeader(prompt: q.questionText, audioUrl: q.audioUrl),
          if (q.imageUrl != null && q.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                q.imageUrl!,
                errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 24),
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _select(i),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _selected == i
                          ? Colors.green
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                    color: _selected == i
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.white,
                  ),
                  child: Column(
                    children: [
                      // IMAGE
                      if (q.options[i].imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            q.options[i].imageUrl,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) =>
                                const SizedBox.shrink(),
                          ),
                        ),

                      // TEXT
                      if (q.options[i].text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            q.options[i].text,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
