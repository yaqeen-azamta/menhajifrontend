class TracingResult {
  final double accuracy;
  final double coverage;
  final double precision;
  final bool isCorrect;
  final int score;
  final String questionId;
  final int timeSpentMs;

  const TracingResult({
    required this.accuracy,
    required this.coverage,
    required this.precision,
    required this.isCorrect,
    required this.score,
    required this.questionId,
    required this.timeSpentMs,
  });

  String get accuracyPercent => '${(accuracy * 100).round()}%';

  int get starRating {
    if (accuracy >= 0.90) return 3;
    if (accuracy >= 0.75) return 2;
    if (accuracy >= 0.60) return 1;
    return 0;
  }

  Map<String, dynamic> toJson() => {
        'accuracy': accuracy,
        'coverage': coverage,
        'precision': precision,
        'isCorrect': isCorrect,
        'score': score,
        'questionId': questionId,
        'timeSpentMs': timeSpentMs,
      };
}