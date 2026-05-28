import '../models/question_model.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────

class QuizQuestionModel {
  final int id;

  // MCQ | TRUE_FALSE | SHORT_ANSWER | IMAGE_MCQ
  final String type;

  final String questionText;

  // ✅ UPDATED
  final List<QuestionOption> options;

  final int difficultyLevel;

  final String? imageUrl;

  final String? audioUrl;

  const QuizQuestionModel({
    required this.id,
    required this.type,
    required this.questionText,
    required this.options,
    required this.difficultyLevel,
    this.imageUrl,
    this.audioUrl,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> j) {
    return QuizQuestionModel(
      id: j['id'] as int,

      type: j['type'] as String? ?? 'MCQ',

      questionText: j['questionText'] as String,

      // ✅ OPTIONS SUPPORT TEXT + IMAGE
      options:
          (j['options'] as List<dynamic>?)
              ?.map((e) => QuestionOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],

      difficultyLevel: j['difficultyLevel'] as int? ?? 1,

      imageUrl: j['imageUrl'] as String?,

      audioUrl: j['audioUrl'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────

class QuizModel {
  final int id;

  final String title;

  final bool gamified;

  final List<QuizQuestionModel> questions;

  // lesson data
  final String? lessonContent;

  final String? lessonObjectives;

  final List<String> lessonImageUrls;

  const QuizModel({
    required this.id,
    required this.title,
    required this.gamified,
    required this.questions,
    this.lessonContent,
    this.lessonObjectives,
    required this.lessonImageUrls,
  });

  factory QuizModel.fromJson(Map<String, dynamic> j) {
    return QuizModel(
      id: j['id'] as int,

      title: j['title'] as String? ?? 'Quiz',

      gamified: j['gamified'] as bool? ?? false,

      questions: (j['questions'] as List<dynamic>? ?? [])
          .map((e) => QuizQuestionModel.fromJson(e as Map<String, dynamic>))
          .toList(),

      lessonContent: j['lessonContent'] as String?,

      lessonObjectives: j['lessonObjectives'] as String?,

      lessonImageUrls:
          (j['lessonImageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

// ─────────────────────────────────────────────────────────────

class AttemptModel {
  final int attemptId;

  final int quizId;

  final String status;

  final double? score;

  final int totalQuestions;

  final int correctAnswers;

  final int pointsEarned;

  const AttemptModel({
    required this.attemptId,
    required this.quizId,
    required this.status,
    this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.pointsEarned,
  });

  factory AttemptModel.fromJson(Map<String, dynamic> j) {
    return AttemptModel(
      attemptId: j['attemptId'] as int,

      quizId: j['quizId'] as int,

      status: j['status'] as String? ?? 'IN_PROGRESS',

      score: (j['score'] as num?)?.toDouble(),

      totalQuestions: j['totalQuestions'] as int? ?? 0,

      correctAnswers: j['correctAnswers'] as int? ?? 0,

      pointsEarned: j['pointsEarned'] as int? ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────

class AnswerResultModel {
  final bool isCorrect;

  final String? feedback;

  final String? correctAnswer;

  final int pointsEarned;

  const AnswerResultModel({
    required this.isCorrect,
    this.feedback,
    this.correctAnswer,
    required this.pointsEarned,
  });

  factory AnswerResultModel.fromJson(Map<String, dynamic> j) {
    return AnswerResultModel(
      isCorrect: j['isCorrect'] as bool? ?? false,

      feedback: j['feedback'] as String?,

      correctAnswer: j['correctAnswer'] as String?,

      pointsEarned: j['pointsEarned'] as int? ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// QuizService
// ─────────────────────────────────────────────────────────────

class QuizService {
  QuizService._();

  static final instance = QuizService._();

  final _api = ApiClient.instance;

  // GET quiz by lesson
  Future<QuizModel> getQuizByLesson(int lessonId) async {
    final res = await _api.get('/api/quiz/lesson/$lessonId');

    return QuizModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  // START attempt
  Future<AttemptModel> startAttempt(int quizId) async {
    final res = await _api.post('/api/quiz/attempt/start/$quizId', {});

    return AttemptModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  // SUBMIT answer
  Future<AnswerResultModel> submitAnswer({
    required int attemptId,
    required int questionId,
    String? answer,
    String? spokenText,
  }) async {
    final res = await _api.post('/api/quiz/attempt/$attemptId/answer', {
      'questionId': questionId,
      // ignore: use_null_aware_elements — ? checks the key, not the value here
      if (answer != null) 'answer': answer,
      // ignore: use_null_aware_elements
      if (spokenText != null) 'spokenText': spokenText,
    });

    return AnswerResultModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  // COMPLETE attempt
  Future<AttemptModel> completeAttempt(int attemptId) async {
    final res = await _api.post('/api/quiz/attempt/$attemptId/complete', {});

    return AttemptModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  // GET hint
  Future<Map<String, dynamic>> getHint(int questionId, {int level = 1}) async {
    final res = await _api.getQuery('/api/quiz/question/$questionId/hint', {
      'level': level.toString(),
    });

    return res['data'] as Map<String, dynamic>;
  }
}
