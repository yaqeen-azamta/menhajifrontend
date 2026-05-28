// ════════════════════════════════════════════════════════════════════════════
// question_callback.dart
// ════════════════════════════════════════════════════════════════════════════
//
// Shared contract between QuizScreen and every question widget.
//
// QuizScreen passes an `onAnswer` callback into each question widget.
// When the student commits their answer, the widget calls this callback
// with a SubmittedAnswer payload. QuizScreen handles network submission,
// feedback display, and progression — widgets stay focused on their UI.
//
// ════════════════════════════════════════════════════════════════════════════

/// What a widget sends up when the student answers.
class SubmittedAnswer {
  /// Primary string answer — sent as `answer` in SubmitAnswerRequest.
  /// For MCQ/true_false: the picked option text.
  /// For fill_blank/reorder_words: the assembled sentence.
  /// For write_answer/voice_answer: the typed/transcribed text.
  final String answer;

  /// Optional separate field for voice — the raw transcript text.
  /// Backend's SubmitAnswerRequest has both `answer` and `spokenText`.
  final String? spokenText;

  /// Optional structured payload (e.g. drag_drop mapping, image_match pairs).
  /// Included for future backends that want richer data. Current backend
  /// only reads `answer`, but we expose this so widgets can attach it
  /// without breaking the contract.
  final Map<String, dynamic>? structured;

  const SubmittedAnswer({
    required this.answer,
    this.spokenText,
    this.structured,
  });
}

/// Signature every question widget uses to report an answer.
typedef OnAnswerSubmitted = void Function(SubmittedAnswer answer);
