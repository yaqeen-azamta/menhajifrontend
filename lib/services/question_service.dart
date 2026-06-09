import 'package:flutter/foundation.dart';

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
      options:
          (json['options'] as List<dynamic>?)?.map((e) {
            if (e is String) return QuestionOption(text: e, imageUrl: '');
            return QuestionOption.fromJson(e as Map<String, dynamic>);
          }).toList() ??
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
  // 5 if this was the first-ever correct answer for this question;
  // 0 if incorrect or if the student already answered it correctly before.
  final int pointsAwarded;

  const SaveAnswerResult({
    required this.isCorrect,
    required this.score,
    this.feedback,
    this.correctAnswer,
    this.pointsAwarded = 0,
  });

  factory SaveAnswerResult.fromJson(Map<String, dynamic> json) {
    final raw = json['isCorrect'];
    final bool isCorrect;
    if (raw is bool) {
      isCorrect = raw;
    } else if (raw is int) {
      isCorrect = raw != 0;
    } else {
      isCorrect = false;
    }
    return SaveAnswerResult(
      isCorrect: isCorrect,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      feedback: json['feedback']?.toString(),
      correctAnswer: json['correctAnswer']?.toString(),
      pointsAwarded: (json['pointsAwarded'] as num?)?.toInt() ?? 0,
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
  Future<List<QuestionModel>> getQuestionsByLesson(int lessonId) async {
    print('🔥🔥🔥 getQuestionsByLesson called');
    print('Lesson ID = $lessonId');

    final res = await _api.get('/api/questions/lesson/$lessonId');

    print('================ API QUESTIONS RESPONSE ================');
    print('Response Type = ${res.runtimeType}');
    print('Full Response = $res');
    print('========================================================');

    final list = res['data'] as List<dynamic>;

    print('================ QUESTIONS AFTER API ==================');
    print('Questions Count = ${list.length}');

    for (final item in list) {
      print('------------------------------------------------');
      print(item);
    }

    print('=======================================================');

    final questions = list
        .map((e) => QuestionModel.fromJson(e as Map<String, dynamic>))
        .toList();

    print('================ AFTER PARSING ==================');

    for (final q in questions) {
      print('ID = ${q.id}');
      print('TEXT = ${q.questionText}');
      print('TYPE = ${q.type}');
      print('OPTIONS COUNT = ${q.options.length}');

      for (final opt in q.options) {
        print('OPTION => text="${opt.text}" image="${opt.imageUrl}"');
      }

      print('--------------------------------');
    }

    print('================================================');

    return questions;
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
    final payload = {
      'questionId': questionId,
      'lessonId': lessonId,
      'answer': answer,
      'questionType': questionType,
    };
    debugPrint('📤 saveAnswer payload: $payload');

    final res = await _api.post('/api/student-answers', payload);

    debugPrint('📥 saveAnswer raw response: $res');

    final data = res['data'] as Map<String, dynamic>;
    final result = SaveAnswerResult.fromJson(data);

    debugPrint('✅ saveAnswer parsed: isCorrect=${result.isCorrect} '
        'points=${result.pointsAwarded} feedback="${result.feedback}"');

    return result;
  }
}
