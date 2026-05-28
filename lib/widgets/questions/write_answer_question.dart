// ════════════════════════════════════════════════════════════════════════════
// write_answer — keyboard input. Student types the answer.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../../../theme/theme.dart';
import '../fat_button.dart';
import '../quiz/question_callback.dart';
import '../quiz/shared/question_header.dart';

class WriteAnswerQuestion extends StatefulWidget {
  const WriteAnswerQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<WriteAnswerQuestion> createState() => _WriteAnswerQuestionState();
}

class _WriteAnswerQuestionState extends State<WriteAnswerQuestion> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onAnswer(SubmittedAnswer(answer: text));
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

          TextField(
            controller: _ctrl,
            enabled: !widget.locked,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'Type your answer...',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFE5E5E5),
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppColors.secondary,
                  width: 2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          FatButton(label: 'Submit', onPressed: widget.locked ? null : _submit),
        ],
      ),
    );
  }
}
