import 'dart:math' as math;
import 'dart:ui';

class AccuracyResult {
  final double coverage;
  final double precision;
  final double overall;

  const AccuracyResult({
    required this.coverage,
    required this.precision,
    required this.overall,
  });

  static const zero = AccuracyResult(coverage: 0, precision: 0, overall: 0);
}

/// Compares user-drawn strokes against pre-sampled guide path points.
///
/// Coverage  – what fraction of the guide path was "touched" by the user.
/// Precision – what fraction of the user's drawing lies near the guide path.
/// Overall   – weighted blend (60 % coverage + 40 % precision).
///
/// Using both metrics prevents cheating: randomly filling the canvas
/// yields high coverage but very low precision, keeping the overall score low.
class AccuracyCalculator {
  final double tolerancePx;

  const AccuracyCalculator({this.tolerancePx = 38.0});

  AccuracyResult calculate({
    required List<List<Offset>> userStrokes,
    required List<Offset> guidePoints,
  }) {
    // Collect all user points, skipping tiny taps (< 3 points per stroke).
    final rawUser = <Offset>[];
    for (final stroke in userStrokes) {
      if (stroke.length >= 3) rawUser.addAll(stroke);
    }

    if (guidePoints.isEmpty || rawUser.length < 5) return AccuracyResult.zero;

    // --- Coverage: % of guide sample points "hit" by any user point ----------
    int covered = 0;
    for (final gp in guidePoints) {
      for (final up in rawUser) {
        if (_dist(gp, up) <= tolerancePx) {
          covered++;
          break;
        }
      }
    }
    final coverage = (covered / guidePoints.length).clamp(0.0, 1.0);

    // --- Precision: % of thinned user points that lie near the guide ---------
    final thinned = _thin(rawUser, minDist: 6.0);
    int onPath = 0;
    for (final up in thinned) {
      for (final gp in guidePoints) {
        if (_dist(up, gp) <= tolerancePx) {
          onPath++;
          break;
        }
      }
    }
    final precision =
        thinned.isEmpty ? 0.0 : (onPath / thinned.length).clamp(0.0, 1.0);

    final overall = (coverage * 0.60 + precision * 0.40).clamp(0.0, 1.0);

    return AccuracyResult(
      coverage: coverage,
      precision: precision,
      overall: overall,
    );
  }

  double _dist(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  // Reduce point density so fast drawing doesn't inflate the precision metric.
  List<Offset> _thin(List<Offset> points, {required double minDist}) {
    if (points.isEmpty) return [];
    final result = [points.first];
    for (final p in points.skip(1)) {
      if (_dist(p, result.last) >= minDist) result.add(p);
    }
    return result;
  }
}