import '../models/tracing_question.dart';
import 'path_definition.dart';

/// Pre-built tracing templates for numbers and letters.
/// All coordinates are normalised to [0, 1] — (0,0) is top-left.
class TracingTemplates {
  TracingTemplates._();

  // ─────────────────────────────────────────────────────────────────────────
  // Number 1
  // One stroke: small flag at top, then a long vertical stem.
  // ─────────────────────────────────────────────────────────────────────────
  static const number1 = TracingQuestion(
    id: 'num_1',
    displayText: '1',
    instruction: 'Trace the number 1',
    category: TracingCategory.number,
    guideStrokes: [
      StrokeDefinition([
        MoveTo(0.40, 0.26), // flag start
        LineTo(0.50, 0.14), // top of stem
        LineTo(0.50, 0.86), // bottom of stem
      ]),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Number 2
  // One stroke: arc over the top → diagonal sweep down-left → base line.
  // ─────────────────────────────────────────────────────────────────────────
  static const number2 = TracingQuestion(
    id: 'num_2',
    displayText: '2',
    instruction: 'Trace the number 2',
    category: TracingCategory.number,
    guideStrokes: [
      StrokeDefinition([
        MoveTo(0.28, 0.36),
        CubicTo(0.26, 0.09, 0.74, 0.09, 0.72, 0.36), // upper arc
        CubicTo(0.72, 0.54, 0.32, 0.63, 0.28, 0.74), // diagonal sweep
        LineTo(0.72, 0.74), // base line
      ]),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Number 3
  // One stroke: upper bump right → back to centre → lower bump right → left.
  // ─────────────────────────────────────────────────────────────────────────
  static const number3 = TracingQuestion(
    id: 'num_3',
    displayText: '3',
    instruction: 'Trace the number 3',
    category: TracingCategory.number,
    guideStrokes: [
      StrokeDefinition([
        MoveTo(0.28, 0.24),
        CubicTo(0.28, 0.07, 0.73, 0.07, 0.73, 0.33), // upper bump
        CubicTo(0.73, 0.46, 0.50, 0.49, 0.50, 0.50), // back to centre
        CubicTo(0.50, 0.51, 0.73, 0.54, 0.73, 0.67), // lower bump
        CubicTo(0.73, 0.90, 0.27, 0.90, 0.27, 0.76), // back bottom-left
      ]),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // English letter A
  // Three strokes: left leg, right leg, crossbar.
  // ─────────────────────────────────────────────────────────────────────────
  static const letterA = TracingQuestion(
    id: 'eng_A',
    displayText: 'A',
    instruction: 'Trace the letter A',
    category: TracingCategory.englishLetter,
    guideStrokes: [
      StrokeDefinition([MoveTo(0.50, 0.12), LineTo(0.20, 0.88)]), // left leg
      StrokeDefinition([MoveTo(0.50, 0.12), LineTo(0.80, 0.88)]), // right leg
      StrokeDefinition([MoveTo(0.32, 0.57), LineTo(0.68, 0.57)]), // crossbar
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Arabic letter ب (Ba)
  // One stroke: right-to-left main body → left hook → along baseline.
  // (Dots are shown decoratively in the guide painter but not traced.)
  // ─────────────────────────────────────────────────────────────────────────
  static const letterBa = TracingQuestion(
    id: 'ar_ba',
    displayText: 'ب',
    instruction: 'Trace the letter ب (Ba)',
    category: TracingCategory.arabicLetter,
    toleranceFraction: 0.10, // slightly more generous for the curve
    guideStrokes: [
      StrokeDefinition([
        MoveTo(0.82, 0.44),
        CubicTo(0.65, 0.38, 0.38, 0.38, 0.26, 0.44), // body going left
        CubicTo(0.18, 0.50, 0.18, 0.62, 0.27, 0.67), // left hook
        CubicTo(0.36, 0.73, 0.58, 0.73, 0.68, 0.67), // along bottom-right
      ]),
    ],
  );

  static const List<TracingQuestion> all = [
    number1,
    number2,
    number3,
    letterA,
    letterBa,
  ];
}