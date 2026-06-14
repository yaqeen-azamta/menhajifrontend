import 'package:flutter/material.dart';
import 'package:tracing_game/tracing_game.dart';

/// Detects the type of content in [text] and builds the appropriate
/// tracing game widget (chars, word, or geometric shape).
class TracingHelper {
  TracingHelper._();

  static Widget buildGameWidget({
    required String text,
    Future<void> Function(int index)? onGameFinished,
    Future<void> Function(int index)? onTracingUpdated,
    Future<void> Function(int index)? onCurrentTracingScreenFinished,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const SizedBox();

    // Geometric shape keyword → shapes game
    final shape = _parseShape(trimmed);
    if (shape != null) {
      return TracingGeometricShapesGame(
        traceGeoMetricShapeModels: [
          TraceGeoMetricShapeModel(
            shapes: [MathShapeWithOption(shape: shape)],
          ),
        ],
        onGameFinished: onGameFinished,
        onTracingUpdated: onTracingUpdated,
        onCurrentTracingScreenFinished: onCurrentTracingScreenFinished,
      );
    }

    // Single supported character → chars game
    if (trimmed.length == 1 && _isTraceable(trimmed)) {
      return TracingCharsGame(
        traceShapeModel: [
          TraceCharsModel(
            chars: [TraceCharModel(char: trimmed)],
          ),
        ],
        onGameFinished: onGameFinished,
        onTracingUpdated: onTracingUpdated,
        onCurrentTracingScreenFinished: onCurrentTracingScreenFinished,
      );
    }

    // Multi-character text → word game (handles Arabic words, English words,
    // mixed numbers/letters; unsupported chars are silently skipped by the
    // underlying TypeExtensionTracking)
    return TracingWordGame(
      words: [TraceWordModel(word: trimmed)],
      onGameFinished: onGameFinished,
      onTracingUpdated: onTracingUpdated,
      onCurrentTracingScreenFinished: onCurrentTracingScreenFinished,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Returns true when the single character [c] is supported by the
  /// tracing engine (Arabic, Latin a-z / A-Z, or a digit 0-9).
  static bool _isTraceable(String c) {
    return RegExp(r'[؀-ۿ]').hasMatch(c) ||
        RegExp(r'^[a-zA-Z0-9]$').hasMatch(c);
  }

  /// Maps common shape keyword strings to [MathShapes] enum values.
  /// Returns null when the text is not a recognised shape name.
  static MathShapes? _parseShape(String text) {
    switch (text.toLowerCase()) {
      case 'circle':
        return MathShapes.circle;
      case 'rectangle':
        return MathShapes.rectangle;
      case 'triangle':
      case 'triangle1':
        return MathShapes.triangle1;
      case 'triangle2':
        return MathShapes.triangle2;
      case 'triangle3':
        return MathShapes.triangle3;
      case 'triangle4':
        return MathShapes.triangle4;
      default:
        return null;
    }
  }
}
