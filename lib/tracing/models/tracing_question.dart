import '../utils/path_definition.dart';

enum TracingCategory { number, englishLetter, arabicLetter, shape }

class TracingQuestion {
  final String id;

  final String displayText;

  final String instruction;

  final TracingCategory category;

  final List<StrokeDefinition> guideStrokes;

  final String? imageUrl;

  /// Tolerance as a fraction of the canvas's smallest dimension (0.0–1.0).
  final double toleranceFraction;

  /// Minimum overall accuracy (0.0–1.0) to count as correct.
  final double minAccuracy;

  final int maxScore;

  const TracingQuestion({
    required this.id,

    required this.displayText,

    required this.instruction,

    required this.category,

    required this.guideStrokes,

    this.imageUrl,

    this.toleranceFraction = 0.09,

    this.minAccuracy = 0.70,

    this.maxScore = 100,
  });

  String get categoryLabel => switch (category) {
    TracingCategory.number => 'Number',
    TracingCategory.englishLetter => 'English',
    TracingCategory.arabicLetter => 'Arabic',
    TracingCategory.shape => 'Shape',
  };
}
