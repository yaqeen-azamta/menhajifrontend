import 'dart:ui';

// ---------------------------------------------------------------------------
// Path command types — sealed so the switch in buildPath is exhaustive.
// ---------------------------------------------------------------------------

sealed class PathCommand {
  const PathCommand();
}

final class MoveTo extends PathCommand {
  final double x, y;
  const MoveTo(this.x, this.y);
}

final class LineTo extends PathCommand {
  final double x, y;
  const LineTo(this.x, this.y);
}

final class CubicTo extends PathCommand {
  final double cp1x, cp1y, cp2x, cp2y, x, y;
  const CubicTo(
    this.cp1x,
    this.cp1y,
    this.cp2x,
    this.cp2y,
    this.x,
    this.y,
  );
}

final class QuadTo extends PathCommand {
  final double cpx, cpy, x, y;
  const QuadTo(this.cpx, this.cpy, this.x, this.y);
}

// ---------------------------------------------------------------------------
// StrokeDefinition — one connected drawing stroke in normalised [0,1] space.
// ---------------------------------------------------------------------------

class StrokeDefinition {
  final List<PathCommand> commands;

  const StrokeDefinition(this.commands);

  /// Builds a Flutter [Path] scaled to [canvasSize].
  Path buildPath(Size canvasSize) {
    final path = Path();
    for (final cmd in commands) {
      switch (cmd) {
        case MoveTo c:
          path.moveTo(c.x * canvasSize.width, c.y * canvasSize.height);
        case LineTo c:
          path.lineTo(c.x * canvasSize.width, c.y * canvasSize.height);
        case CubicTo c:
          path.cubicTo(
            c.cp1x * canvasSize.width,
            c.cp1y * canvasSize.height,
            c.cp2x * canvasSize.width,
            c.cp2y * canvasSize.height,
            c.x * canvasSize.width,
            c.y * canvasSize.height,
          );
        case QuadTo c:
          path.quadraticBezierTo(
            c.cpx * canvasSize.width,
            c.cpy * canvasSize.height,
            c.x * canvasSize.width,
            c.y * canvasSize.height,
          );
      }
    }
    return path;
  }

  /// Samples the path into evenly-spaced [Offset] points for accuracy checks.
  List<Offset> samplePoints(Size canvasSize, {int totalSamples = 200}) {
    final path = buildPath(canvasSize);
    final points = <Offset>[];
    for (final metric in path.computeMetrics()) {
      if (metric.length == 0) continue;
      for (int i = 0; i <= totalSamples; i++) {
        final t = (i / totalSamples) * metric.length;
        final tangent = metric.getTangentForOffset(t.clamp(0.0, metric.length));
        if (tangent != null) points.add(tangent.position);
      }
    }
    return points;
  }

  /// Returns the first [MoveTo] point in canvas coordinates.
  Offset? startPoint(Size canvasSize) {
    for (final cmd in commands) {
      if (cmd is MoveTo) {
        return Offset(cmd.x * canvasSize.width, cmd.y * canvasSize.height);
      }
    }
    return null;
  }

  /// Returns the path's terminal point in canvas coordinates.
  Offset? endPoint(Size canvasSize) {
    final path = buildPath(canvasSize);
    Offset? last;
    for (final metric in path.computeMetrics()) {
      final t = metric.getTangentForOffset(metric.length);
      if (t != null) last = t.position;
    }
    return last;
  }

  /// Returns (position, direction) pairs for drawing arrow hints.
  List<(Offset, Offset)> arrowPoints(
    Size canvasSize, {
    double intervalPx = 65,
  }) {
    final path = buildPath(canvasSize);
    final result = <(Offset, Offset)>[];
    for (final metric in path.computeMetrics()) {
      if (metric.length < intervalPx * 1.5) continue;
      double dist = intervalPx;
      while (dist < metric.length - intervalPx * 0.4) {
        final t = metric.getTangentForOffset(dist);
        if (t != null) result.add((t.position, t.vector));
        dist += intervalPx;
      }
    }
    return result;
  }

  /// Total arc-length of this stroke in canvas pixels.
  double arcLength(Size canvasSize) {
    double len = 0;
    for (final m in buildPath(canvasSize).computeMetrics()) {
      len += m.length;
    }
    return len;
  }

  /// Returns [intervalPx]-spaced dot positions along the path (for dotted preview).
  List<Offset> dottedPoints(Size canvasSize, {double intervalPx = 18}) {
    final path = buildPath(canvasSize);
    final result = <Offset>[];
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist <= metric.length) {
        final t = metric.getTangentForOffset(dist.clamp(0.0, metric.length));
        if (t != null) result.add(t.position);
        dist += intervalPx;
      }
    }
    return result;
  }

}