import 'api_client.dart';

// ─────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────

class QuestionOption {
  final String text;
  final String imageUrl;

  const QuestionOption({required this.text, required this.imageUrl});

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      text: json['text']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
    );
  }
}

class QuestionModel {
  final int id;
  final String questionText;
  final String? imageUrl;
  final List<QuestionOption> options;
  final String? correctAnswer;
  final String? type;

  const QuestionModel({
    required this.id,
    required this.questionText,
    required this.options,
    this.imageUrl,
    this.correctAnswer,
    this.type,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as int,
      questionText: json['questionText']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      correctAnswer: json['correctAnswer']?.toString(),
      type: json['type']?.toString(),
      options: (json['options'] as List<dynamic>?)
              ?.map((e) {
                if (e is String) return QuestionOption(text: e, imageUrl: '');
                return QuestionOption.fromJson(e as Map<String, dynamic>);
              })
              .toList() ??
          [],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SaveAnswerResult — returned by saveAnswer()
// ─────────────────────────────────────────────────────────────

class SaveAnswerResult {
  final bool isCorrect;
  final double score;
  final String? feedback;
  final String? correctAnswer;

  const SaveAnswerResult({
    required this.isCorrect,
    required this.score,
    this.feedback,
    this.correctAnswer,
  });

  factory SaveAnswerResult.fromJson(Map<String, dynamic> json) {
    return SaveAnswerResult(
      isCorrect: json['isCorrect'] as bool? ?? false,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      feedback: json['feedback']?.toString(),
      correctAnswer: json['correctAnswer']?.toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// QuestionService
// ─────────────────────────────────────────────────────────────

class QuestionService {
  QuestionService._();
  static final instance = QuestionService._();

  final _api = ApiClient.instance;

  // GET /api/questions/lesson/{lessonId}
  Future<List<QuestionModel>> getQuestionsByLesson(int lessonId) async {
    final res = await _api.get('/api/questions/lesson/$lessonId');
    final list = res['data'] as List<dynamic>;
    return list
        .map((e) => QuestionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // POST /api/student-answers
  // answer: the student's response string.
  // For TRACING questions pass 'TRACED' as the answer.
  Future<SaveAnswerResult> saveAnswer({
    required int questionId,
    required int lessonId,
    required String answer,
    required String questionType,
  }) async {
    final res = await _api.post('/api/student-answers', {
      'questionId': questionId,
      'lessonId': lessonId,
      'answer': answer,
      'questionType': questionType,
    });
    final data = res['data'] as Map<String, dynamic>;
    return SaveAnswerResult.fromJson(data);
  }
}
