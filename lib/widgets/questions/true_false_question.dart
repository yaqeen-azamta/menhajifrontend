import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../quiz/question_callback.dart';
import '../quiz/shared/option_tile.dart';
import '../quiz/shared/question_header.dart';

class TrueFalseQuestion extends StatefulWidget {
  const TrueFalseQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<TrueFalseQuestion> createState() => _TrueFalseQuestionState();
}

class _TrueFalseQuestionState extends State<TrueFalseQuestion> {
  String? _selected;

  void _pick(String value) {
    setState(() => _selected = value);

    widget.onAnswer(SubmittedAnswer(answer: value));
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    final trueLabel = q.options[0].text;

    final falseLabel = q.options[1].text;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestionHeader(prompt: q.questionText, audioUrl: q.audioUrl),

          const SizedBox(height: 24),

          OptionTile(
            label: trueLabel,
            locked: widget.locked,
            state: _selected == trueLabel
                ? OptionState.selected
                : OptionState.idle,
            onTap: () => _pick(trueLabel),
          ),

          const SizedBox(height: 12),

          OptionTile(
            label: falseLabel,
            locked: widget.locked,
            state: _selected == falseLabel
                ? OptionState.selected
                : OptionState.idle,
            onTap: () => _pick(falseLabel),
          ),
        ],
      ),
    );
  }
}
