// ════════════════════════════════════════════════════════════════════════════
// question_renderer.dart
// ════════════════════════════════════════════════════════════════════════════
//
// Dynamic dispatcher. Given a Question, render the correct widget.
//
// QuizScreen always uses QuestionRenderer — it never imports the individual
// question widgets directly. This keeps QuizScreen unaware of how each
// type renders, so you can add new types without touching QuizScreen.
//
// To ADD a new question type:
//   1. Add the enum to QuestionType in question_model.dart
//   2. Create the widget in widgets/quiz/questions/
//   3. Add a `case` in the switch below
//
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import 'question_callback.dart';
import '../questions/drag_drop_question.dart';
import '../questions/fill_blank_question.dart';
import '../questions/image_match_question.dart';
import '../questions/listen_and_choose_question.dart';
import '../questions/mcq_question.dart';
import '../questions/reorder_words_question.dart';
import '../questions/true_false_question.dart';
import '../questions/voice_answer_question.dart';
import '../questions/write_answer_question.dart';

class QuestionRenderer extends StatelessWidget {
  const QuestionRenderer({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;

  /// When true, the widget should disable interaction (e.g. after submission
  /// while feedback is showing).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    // Animated swap between question widgets for smooth transitions
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(question.id), child: _buildForType()),
    );
  }

  Widget _buildForType() {
    switch (question.type) {
      case QuestionType.mcq:
        return McqQuestion(
          question: question,
          onAnswer: onAnswer,
          locked: locked,
        );
      case QuestionType.trueFalse:
        return TrueFalseQuestion(
          question: question,
          onAnswer: onAnswer,
          locked: locked,
        );
      case QuestionType.fillBlank:
        return FillBlankQuestion(
          question: question,
          onAnswer: onAnswer,
          locked: locked,
        );
      case QuestionType.voiceAnswer:
        return VoiceAnswerQuestion(
          question: question,
          onAnswer: onAnswer,
          locked: locked,
        );
      case QuestionType.imageMatch:
        return ImageMatchQuestion(
          question: question,
          onAnswer: onAnswer,
          locked: locked,
        );
      case QuestionType.dragDrop:
        return DragDropQuestion(
          question: question,
          onAnswer: onAnswer,
          locked: locked,
        );
      case QuestionType.reorderWords:
        return ReorderWordsQuestion(
          question: question,
          onAnswer: onAnswer,
          locked: locked,
        );
      case QuestionType.listenAndChoose:
        return ListenAndChooseQuestion(
          question: question,
          onAnswer: onAnswer,
          locked: locked,
        );
      case QuestionType.writeAnswer:
        return WriteAnswerQuestion(
          question: question,
          onAnswer: onAnswer,
          locked: locked,
        );
      case QuestionType.unknown:
        return _UnsupportedQuestion(question: question);
      case QuestionType.imageMcq:
        return McqQuestion(
          question: question,
          onAnswer: onAnswer,
          locked: locked,
        );
      case QuestionType.reading:
        return const SizedBox.shrink();
    }
  }
}

// Fallback for unknown types — graceful degradation instead of crashing.
class _UnsupportedQuestion extends StatelessWidget {
  const _UnsupportedQuestion({required this.question});
  final Question question;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🤔 Unknown question type',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(question.questionText),
        ],
      ),
    );
  }
}
