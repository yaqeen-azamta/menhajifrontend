// ════════════════════════════════════════════════════════════════════════════
// question_model.dart
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

/// All supported question types.
enum QuestionType {
  mcq,
  trueFalse,
  fillBlank,
  voiceAnswer,
  reading,
  story,
  imageMatch,
  dragDrop,
  reorderWords,
  listenAndChoose,
  writeAnswer,
  imageMcq,
  countGroup,
  matching,
  coloring,
  tracing,
  letterCompletion,
  unknown;

  static QuestionType parse(String? raw) {
    if (raw == null) return QuestionType.unknown;

    final s = raw.toLowerCase().replaceAll('-', '_');

    switch (s) {
      case 'mcq':
      case 'multiple_choice':
        return QuestionType.mcq;

      case 'image_mcq':
      case 'image_multiple_choice':
        return QuestionType.imageMcq;

      case 'true_false':
      case 'truefalse':
        return QuestionType.trueFalse;

      case 'fill_blank':
      case 'fillblank':
      case 'fill_in_blank':
        return QuestionType.fillBlank;

      case 'voice_answer':
      case 'voice':
      case 'pronunciation':
      case 'short_answer':
        return QuestionType.voiceAnswer;

      case 'image_match':
      case 'imagematch':
      case 'match':
        return QuestionType.imageMatch;

      case 'drag_drop':
      case 'dragdrop':
      case 'drag_and_drop':
        return QuestionType.dragDrop;

      case 'reorder_words':
      case 'reorder':
      case 'word_order':
        return QuestionType.reorderWords;

      case 'listen_and_choose':
      case 'listen':
        return QuestionType.listenAndChoose;

      case 'write_answer':
      case 'write':
      case 'text':
        return QuestionType.writeAnswer;

      case 'reading':
        return QuestionType.reading;

      case 'story':
        return QuestionType.story;

      case 'count_group':
      case 'countgroup':
        return QuestionType.countGroup;

      case 'matching':
        return QuestionType.matching;

      case 'coloring':
      case 'colouring':
        return QuestionType.coloring;

      case 'tracing':
        return QuestionType.tracing;

      case 'letter_completion':
      case 'lettercompletion':
        return QuestionType.letterCompletion;

      default:
        return QuestionType.unknown;
    }
  }
}

// ───────────────── OPTION MODEL ─────────────────

class QuestionOption {
  final String text;
  final String imageUrl;

  const QuestionOption({required this.text, required this.imageUrl});

  factory QuestionOption.fromJson(Map<String, dynamic> j) {
    return QuestionOption(
      text: j['text'] as String? ?? '',
      imageUrl: j['imageUrl'] as String? ?? '',
    );
  }
}

// ───────────────── QUESTION MODEL ─────────────────

class QuestionModel {
  final int id;

  final String questionText;

  final String? imageUrl;

  final List<QuestionOption> options;

  final String? correctAnswer;

  final String? type;

  QuestionModel({
    required this.id,
    required this.questionText,
    required this.options,
    this.imageUrl,
    this.correctAnswer,
    this.type,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'],

      questionText: json['questionText'] ?? '',

      imageUrl: json['imageUrl'],

      correctAnswer: json['correctAnswer'],

      type: json['type'],

      // ✅ FIXED
      options:
          (json['options'] as List<dynamic>?)?.map((e) {
            // OLD FORMAT
            if (e is String) {
              return QuestionOption(text: e, imageUrl: '');
            }

            // NEW FORMAT
            return QuestionOption.fromJson(e as Map<String, dynamic>);
          }).toList() ??
          [],
    );
  }
}
// ════════════════════════════════════════════════════════════════════════════
// MATCH PAIR MODEL
// ════════════════════════════════════════════════════════════════════════════

class MatchPair {
  final String id;
  final String? text;
  final String? imageUrl;

  const MatchPair({required this.id, this.text, this.imageUrl});

  factory MatchPair.fromJson(Map<String, dynamic> j) {
    return MatchPair(
      id: (j['id'] ?? '').toString(),
      text: j['text'] as String?,
      imageUrl: j['imageUrl'] as String?,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// COLORING OBJECT MODEL
// ════════════════════════════════════════════════════════════════════════════

/// One object group in a COLORING question.
/// [image]         — relative or absolute URL of the outline image.
/// [targetColor]   — the color the student must apply ("red", "green", …).
/// [requiredCount] — how many of this object must be colored.
/// [totalCount]    — how many object tiles to display (≥ requiredCount).
///                   Defaults to requiredCount + 2 when not supplied by server.
@immutable
class ColoringObject {
  final String image;
  final String targetColor;
  final int requiredCount;
  final int totalCount;

  const ColoringObject({
    required this.image,
    required this.targetColor,
    required this.requiredCount,
    required this.totalCount,
  });

  factory ColoringObject.fromJson(Map<String, dynamic> j) {
    final req = (j['requiredCount'] as num?)?.toInt() ?? 1;
    return ColoringObject(
      image: j['image'] as String? ?? '',
      targetColor: j['targetColor'] as String? ?? 'red',
      requiredCount: req,
      totalCount: (j['totalCount'] as num?)?.toInt() ?? (req + 2),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// QUESTION MODEL
// ════════════════════════════════════════════════════════════════════════════

@immutable
class Question {
  // ── Core ─────────────────────────────────────────────

  final int id;
  final QuestionType type;
  final String questionText;
  final int difficultyLevel;

  final String? imageUrl;
  final String? audioUrl;
  final String? hint;

  // ── OPTIONS ──────────────────────────────────────────

  final List<QuestionOption> options;

  // ── Fill blank ───────────────────────────────────────

  final List<String> wordBank;

  // ── Drag/drop/reorder ────────────────────────────────

  final List<String> tokens;
  final List<String> targets;

  // ── Image match / MATCHING ───────────────────────────

  final List<MatchPair> leftPairs;
  final List<MatchPair> rightPairs;

  // ── Voice/write ──────────────────────────────────────

  final String? expectedText;

  // ── COLORING ─────────────────────────────────────────

  final List<ColoringObject> coloringObjects;

  // ── LETTER_COMPLETION ─────────────────────────────────

  final List<String> letters;
  final List<String> words;
  final List<String> correctAnswers;

  // ── Raw ──────────────────────────────────────────────

  final Map<String, dynamic> raw;

  const Question({
    required this.id,
    required this.type,
    required this.questionText,
    required this.difficultyLevel,
    this.imageUrl,
    this.audioUrl,
    this.hint,
    this.options = const [],
    this.wordBank = const [],
    this.tokens = const [],
    this.targets = const [],
    this.leftPairs = const [],
    this.rightPairs = const [],
    this.expectedText,
    this.coloringObjects = const [],
    this.letters = const [],
    this.words = const [],
    this.correctAnswers = const [],
    this.raw = const {},
  });

  factory Question.fromJson(Map<String, dynamic> j) {
    // ── Helpers ────────────────────────────────────────────────────────────

    List<String> stringList(dynamic v) =>
        (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];

    // Supports both ["A","B"] and [{text:"",imageUrl:""}] formats.
    List<QuestionOption> optionList(dynamic v) {
      if (v == null) return const [];
      return (v as List<dynamic>).map((e) {
        if (e is String) return QuestionOption(text: e, imageUrl: '');
        return QuestionOption.fromJson(e as Map<String, dynamic>);
      }).toList();
    }

    // Parses [{id,text?,imageUrl?}] into MatchPair list.
    List<MatchPair> pairList(dynamic v) =>
        (v as List<dynamic>?)
            ?.map((e) => MatchPair.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    // ── Type detection ─────────────────────────────────────────────────────
    final type = QuestionType.parse(j['type'] as String?);

    // ── OPTIONS ────────────────────────────────────────────────────────────
    // COUNT_GROUP: prefer rich optionObjects (carries imageUrl per option).
    // All other types: use the plain options array.
    final List<QuestionOption> resolvedOptions;
    if (type == QuestionType.countGroup && j['optionObjects'] != null) {
      resolvedOptions = optionList(j['optionObjects']);
    } else {
      resolvedOptions = optionList(j['options']);
    }

    // ── MATCHING left/right columns ────────────────────────────────────────
    // Server sends leftItems/rightItems for MATCHING questions.
    // Existing IMAGE_MATCH keeps using leftPairs/rightPairs (backward compat).
    final List<MatchPair> resolvedLeft;
    final List<MatchPair> resolvedRight;
    if (type == QuestionType.matching) {
      resolvedLeft = pairList(j['leftItems'] ?? j['leftPairs']);
      resolvedRight = pairList(j['rightItems'] ?? j['rightPairs']);
    } else {
      resolvedLeft = pairList(j['leftPairs']);
      resolvedRight = pairList(j['rightPairs']);
    }

    // ── COLORING objects ───────────────────────────────────────────────────
    List<ColoringObject> coloringObjectList(dynamic v) {
      if (v == null) return const [];
      return (v as List<dynamic>)
          .map((e) => ColoringObject.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Question(
      id: j['id'] as int,
      type: type,
      questionText: j['questionText'] as String? ?? '',
      difficultyLevel: j['difficultyLevel'] as int? ?? 1,
      imageUrl: j['imageUrl'] as String?,
      audioUrl: j['audioUrl'] as String?,
      hint: j['hint'] as String?,
      options: resolvedOptions,
      wordBank: stringList(j['wordBank']),
      tokens: stringList(j['tokens']),
      targets: stringList(j['targets']),
      leftPairs: resolvedLeft,
      rightPairs: resolvedRight,
      expectedText:
          j['expectedText'] as String? ?? j['correctAnswer'] as String?,
      coloringObjects: coloringObjectList(j['coloringObjects']),
      letters: stringList(j['letters']),
      words: stringList(j['words']),
      correctAnswers: stringList(j['correctAnswers']),
      raw: j,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// QUIZ DOCUMENT
// ════════════════════════════════════════════════════════════════════════════

@immutable
class QuizDocument {
  final int id;
  final String title;
  final bool gamified;

  final List<Question> questions;

  final String? lessonContent;
  final String? lessonObjectives;

  final List<String> lessonImageUrls;

  const QuizDocument({
    required this.id,
    required this.title,
    required this.gamified,
    required this.questions,
    this.lessonContent,
    this.lessonObjectives,
    this.lessonImageUrls = const [],
  });

  factory QuizDocument.fromJson(Map<String, dynamic> j) {
    return QuizDocument(
      id: j['id'] as int,

      title: j['title'] as String? ?? 'Quiz',

      gamified: j['gamified'] as bool? ?? false,

      questions: (j['questions'] as List<dynamic>? ?? [])
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList(),

      lessonContent: j['lessonContent'] as String?,

      lessonObjectives: j['lessonObjectives'] as String?,

      lessonImageUrls:
          (j['lessonImageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ANSWER RESULT
// ════════════════════════════════════════════════════════════════════════════
@immutable
class AnswerResult {
  final bool isCorrect;
  final String? feedback;
  final String? correctAnswer;
  final int pointsEarned;

  const AnswerResult({
    required this.isCorrect,
    this.feedback,
    this.correctAnswer,
    required this.pointsEarned,
  });

  factory AnswerResult.fromJson(Map<String, dynamic> j) {
    final raw = j['isCorrect'];

    bool parsedCorrect = false;

    if (raw is bool) {
      parsedCorrect = raw;
    } else if (raw is int) {
      parsedCorrect = raw == 1;
    }

    return AnswerResult(
      isCorrect: parsedCorrect,

      feedback: j['feedback'] as String?,

      correctAnswer: j['correctAnswer'] as String?,

      pointsEarned: j['pointsEarned'] as int? ?? 0,
    );
  }
}
