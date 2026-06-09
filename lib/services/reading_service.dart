import 'dart:io';

import 'api_client.dart';

// ─────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────

/// The reading paragraph and its metadata, returned by the backend.
class ReadingTextModel {
  final String lessonId;
  final String title;
  final String text;

  const ReadingTextModel({
    required this.lessonId,
    required this.title,
    required this.text,
  });

  factory ReadingTextModel.fromJson(Map<String, dynamic> json) {
    // Backend may wrap payload in {data: {...}} or return it directly.
    final d = json['data'] as Map<String, dynamic>? ?? json;
    return ReadingTextModel(
      lessonId: d['lessonId']?.toString() ?? '',
      title: d['title'] as String? ?? '',
      // Accept either 'text' or 'content' from the backend.
      text: d['text'] as String? ?? d['content'] as String? ?? '',
    );
  }
}

/// Full assessment result returned by POST /api/reading/transcribe.
///
/// Backend contract:
/// ```json
/// {
///   "originalText":       "...",
///   "recognizedText":     "...",
///   "pronunciationScore": 87,
///   "accuracy":           87,
///   "feedback":           "جيد",
///   "correctWords":       [...],
///   "incorrectWords":     [...],
///   "missingWords":       [...],
///   "wrongLetters":       ["ث"],
///   "missingLetters":     [],
///   "extraLetters":       [],
///   "characterFeedback":  "انطق حرف الثاء بوضع اللسان بين الأسنان"
/// }
/// ```
class ReadingAssessmentResult {
  final String originalText;
  final String recognizedText;

  /// Levenshtein-based score (0–100). Identical to [pronunciationScore].
  final int accuracy;

  /// Same value as [accuracy], exposed under the backend's primary key name.
  final int pronunciationScore;

  /// Arabic tier label: ممتاز / جيد / يحتاج تحسين / حاول مرة أخرى
  final String feedback;

  final List<String> correctWords;
  final List<String> incorrectWords;
  final List<String> missingWords;

  /// Target letters that were substituted (mispronounced as a different letter).
  final List<String> wrongLetters;

  /// Target letters absent from the transcription (student skipped them).
  final List<String> missingLetters;

  /// Letters present in transcription but absent from target (extra sounds).
  final List<String> extraLetters;

  /// Per-letter Arabic pronunciation tips; empty when no character errors.
  final String characterFeedback;

  const ReadingAssessmentResult({
    required this.originalText,
    required this.recognizedText,
    required this.accuracy,
    required this.pronunciationScore,
    required this.feedback,
    required this.correctWords,
    required this.incorrectWords,
    required this.missingWords,
    this.wrongLetters = const [],
    this.missingLetters = const [],
    this.extraLetters = const [],
    this.characterFeedback = '',
  });

  factory ReadingAssessmentResult.fromJson(Map<String, dynamic> json) {
    final d = json['data'] as Map<String, dynamic>? ?? json;

    List<String> toStrings(dynamic raw) =>
        (raw as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];

    final score =
        (d['pronunciationScore'] as num?)?.toInt() ??
        (d['accuracy'] as num?)?.toInt() ??
        0;

    return ReadingAssessmentResult(
      originalText: d['originalText'] as String? ?? '',
      recognizedText: d['recognizedText'] as String? ?? '',
      accuracy: score,
      pronunciationScore: score,
      feedback: d['feedback'] as String? ?? '',
      correctWords: toStrings(d['correctWords']),
      incorrectWords: toStrings(d['incorrectWords']),
      missingWords: toStrings(d['missingWords']),
      wrongLetters: toStrings(d['wrongLetters']),
      missingLetters: toStrings(d['missingLetters']),
      extraLetters: toStrings(d['extraLetters']),
      characterFeedback: d['characterFeedback'] as String? ?? '',
    );
  }

  // ── Convenience helpers ───────────────────────────────────

  bool get isPerfect => pronunciationScore >= 100;
  bool get isExcellent => pronunciationScore >= 90;
  bool get isGood => pronunciationScore >= 70 && pronunciationScore < 90;
  bool get needsImprovement =>
      pronunciationScore >= 50 && pronunciationScore < 70;
  bool get tryAgain => pronunciationScore < 50;

  int get totalWords =>
      correctWords.length + incorrectWords.length + missingWords.length;
}

// ─────────────────────────────────────────────────────────────
// ReadingService — singleton, follows the existing project pattern
//
// Architecture notes:
//   • Singleton accessed via ReadingService.instance (same as
//     LessonService, VoiceService, AuthService, etc.)
//   • All HTTP calls go through ApiClient.instance which handles
//     JWT token management and silent token refresh.
//   • File uploads use ApiClient.postMultipart() consistent with
//     VoiceService.stopAndTranscribe() and stopAndTranscribeForQuiz().
//
// Future extension points (Phase 2+):
//   • assessPronunciation()  → POST /api/reading/pronunciation
//     For per-word pronunciation scoring with phoneme-level feedback.
//   • fetchWordGuide()       → GET  /api/reading/word/{word}/guide
//     For word-by-word pronunciation practice sessions.
//   • streamTranscription()  → WebSocket /ws/reading/stream
//     For real-time word highlighting while the student reads.
// ─────────────────────────────────────────────────────────────

class ReadingService {
  ReadingService._();
  static final instance = ReadingService._();

  final _api = ApiClient.instance;

  // ── Fetch reading paragraph ───────────────────────────────
  //
  // GET /api/reading/lesson/{lessonId}
  // Response: { data: { lessonId, title, text } }

  Future<ReadingTextModel> fetchReadingText(String lessonId) async {
    final res = await _api.get('/api/reading/lesson/$lessonId');
    return ReadingTextModel.fromJson(res);
  }

  // ── Submit audio for assessment ───────────────────────────
  //
  // POST /api/reading/transcribe  (multipart/form-data)
  //   field "audio"      → m4a audio recording
  //   field "lessonText" → the original paragraph text
  //
  // The caller is responsible for deleting [audioFile] after this
  // method returns (whether it succeeds or throws).
  Future<ReadingAssessmentResult> transcribeReading({
    required File audioFile,
    required String lessonId,
    required int questionId,
  }) async {
    final res = await _api.postMultipart(
      '/api/reading/assess',
      fileField: 'audio',
      file: audioFile,
      filename: 'reading.m4a',
      mimeType: 'audio/m4a',
      fields: {
        'lessonId': lessonId,
        'questionId': questionId.toString(),
        'language': 'ar',
      },
    );

    return ReadingAssessmentResult.fromJson(res);
  }
}
