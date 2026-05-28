import 'tracing_point.dart';
import 'tracing_result.dart';

class TracingSubmission {
  final String studentId;
  final String questionId;
  final List<List<TracingPoint>> strokes;
  final TracingResult result;

  const TracingSubmission({
    required this.studentId,
    required this.questionId,
    required this.strokes,
    required this.result,
  });

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'questionId': questionId,
        'strokes': strokes
            .map((s) => s.map((p) => p.toJson()).toList())
            .toList(),
        'accuracy': result.accuracy,
        'score': result.score,
        'isCorrect': result.isCorrect,
        'timeSpentMs': result.timeSpentMs,
      };
}