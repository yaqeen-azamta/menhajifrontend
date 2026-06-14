// Models for the new adaptive quiz backend API.
//
// Endpoints covered:
//   GET  /api/quiz/adaptive/{lessonId}
//   POST /api/quiz/adaptive/{attemptId}/submit
//   GET  /api/quiz/adaptive/{attemptId}/question/{questionIndex}/hint?level=N

// ─────────────────────────────────────────────────────────────
// Single question inside an adaptive quiz payload
// ─────────────────────────────────────────────────────────────

class AdaptiveQuizItem {
  final String questionText;

  // MCQ | TRUE_FALSE | SHORT_ANSWER
  final String type;

  // Options for MCQ and TRUE_FALSE; empty for SHORT_ANSWER.
  final List<String> options;

  final int questionIndex;

  const AdaptiveQuizItem({
    required this.questionText,
    required this.type,
    required this.options,
    required this.questionIndex,
  });

  factory AdaptiveQuizItem.fromJson(Map<String, dynamic> j) => AdaptiveQuizItem(
    questionText: j['questionText'] as String? ?? '',
    type: (j['type'] as String? ?? 'MCQ').toUpperCase(),
    options: (j['options'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    questionIndex: j['questionIndex'] as int? ?? 0,
  );
}

// ─────────────────────────────────────────────────────────────
// Full payload returned by GET /api/quiz/adaptive/{lessonId}
// May be a freshly generated quiz OR a resumed IN_PROGRESS attempt.
// ─────────────────────────────────────────────────────────────

class AdaptiveQuizPayload {
  final int attemptId;
  final int difficulty;
  final List<String> focusSkills;
  final List<AdaptiveQuizItem> questions;

  const AdaptiveQuizPayload({
    required this.attemptId,
    required this.difficulty,
    required this.focusSkills,
    required this.questions,
  });

  factory AdaptiveQuizPayload.fromJson(Map<String, dynamic> j) =>
      AdaptiveQuizPayload(
        attemptId: j['attemptId'] as int,
        difficulty: j['difficulty'] as int? ?? 1,
        focusSkills: (j['focusSkills'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        questions: (j['questions'] as List<dynamic>? ?? [])
            .map((e) => AdaptiveQuizItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ─────────────────────────────────────────────────────────────
// Single answer inside the submit request body
// ─────────────────────────────────────────────────────────────

class AdaptiveAnswer {
  final int questionIndex;
  final String answer;

  const AdaptiveAnswer({required this.questionIndex, required this.answer});

  Map<String, dynamic> toJson() => {
    'questionIndex': questionIndex,
    'answer': answer,
  };
}

// ─────────────────────────────────────────────────────────────
// Per-question feedback inside the submit response
// ─────────────────────────────────────────────────────────────

class AdaptiveAnswerFeedback {
  final int questionIndex;
  final bool isCorrect;
  final String? correctAnswer;
  final String? explanation;

  const AdaptiveAnswerFeedback({
    required this.questionIndex,
    required this.isCorrect,
    this.correctAnswer,
    this.explanation,
  });

  factory AdaptiveAnswerFeedback.fromJson(Map<String, dynamic> j) =>
      AdaptiveAnswerFeedback(
        questionIndex: j['questionIndex'] as int? ?? 0,
        isCorrect: j['isCorrect'] as bool? ?? false,
        correctAnswer: j['correctAnswer'] as String?,
        explanation: j['explanation'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────
// Updated skill performance entry inside the submit response
// ─────────────────────────────────────────────────────────────

class SkillSummary {
  final String skillName;
  final int level;
  final double mastery;

  const SkillSummary({
    required this.skillName,
    required this.level,
    required this.mastery,
  });

  factory SkillSummary.fromJson(Map<String, dynamic> j) => SkillSummary(
    skillName: j['skillName'] as String? ?? j['name'] as String? ?? '',
    level: j['level'] as int? ?? 1,
    mastery: (j['mastery'] as num?)?.toDouble() ?? 0.0,
  );
}

// ─────────────────────────────────────────────────────────────
// Full result returned by POST /api/quiz/adaptive/{attemptId}/submit
// ─────────────────────────────────────────────────────────────

class AdaptiveQuizResult {
  final int score;
  final int correctCount;

  // Derived on the client from the payload question count since the
  // backend submit response does not include a totalCount field.
  final int totalCount;

  final List<AdaptiveAnswerFeedback> feedback;
  final List<SkillSummary> updatedSkills;

  const AdaptiveQuizResult({
    required this.score,
    required this.correctCount,
    required this.totalCount,
    required this.feedback,
    required this.updatedSkills,
  });

  int get incorrectCount => totalCount - correctCount;

  factory AdaptiveQuizResult.fromJson(
    Map<String, dynamic> j, {
    required int totalCount,
  }) => AdaptiveQuizResult(
    score: j['score'] as int? ?? 0,
    correctCount: j['correctCount'] as int? ?? 0,
    totalCount: totalCount,
    feedback: (j['feedback'] as List<dynamic>?)
            ?.map(
              (e) =>
                  AdaptiveAnswerFeedback.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        const [],
    updatedSkills: (j['updatedSkills'] as List<dynamic>?)
            ?.map(
              (e) => SkillSummary.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        const [],
  );
}
