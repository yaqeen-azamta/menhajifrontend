import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../models/tracing_point.dart';
import '../models/tracing_question.dart';
import '../painters/guide_painter.dart';
import '../painters/user_drawing_painter.dart';

/// Simple tracing canvas:
/// • worksheet background
/// • image from database
/// • free drawing
class TracingCanvasWidget extends StatefulWidget {
  final TracingQuestion question;

  const TracingCanvasWidget({super.key, required this.question});

  @override
  State<TracingCanvasWidget> createState() => TracingCanvasState();
}

class TracingCanvasState extends State<TracingCanvasWidget> {
  // ───────────────── USER DRAWING ─────────────────

  final List<List<Offset>> _strokes = [];

  List<Offset> _currentStroke = [];

  // ───────────────── BACKEND EXPORT ───────────────

  final List<List<TracingPoint>> _tracingStrokes = [];

  List<TracingPoint> _currentTracing = [];

  // ───────────────── PUBLIC GETTERS ───────────────

  List<List<Offset>> get validStrokes => _strokes;

  List<List<TracingPoint>> get tracingStrokes => _tracingStrokes;

  // Dummy values for compatibility
  List<Offset> get guidePoints => [];

  Size get canvasSize => Size.zero;

  // ───────────────── CLEAR ────────────────────────

  void clear() {
    setState(() {
      _strokes.clear();

      _tracingStrokes.clear();

      _currentStroke = [];

      _currentTracing = [];
    });
  }

  @override
  void didUpdateWidget(covariant TracingCanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.question.id != widget.question.id) {
      clear();
    }
  }

  // ───────────────── DRAWING ──────────────────────

  void _onPanStart(DragStartDetails details) {
    final p = details.localPosition;

    _currentStroke = [p];

    _currentTracing = [
      TracingPoint(
        x: p.dx,
        y: p.dy,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final p = details.localPosition;

    setState(() {
      _currentStroke.add(p);

      _currentTracing.add(
        TracingPoint(
          x: p.dx,
          y: p.dy,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke.length < 2) {
      _currentStroke = [];

      _currentTracing = [];

      return;
    }

    setState(() {
      _strokes.add(List.from(_currentStroke));

      _tracingStrokes.add(List.from(_currentTracing));

      _currentStroke = [];

      _currentTracing = [];
    });
  }

  // ───────────────── BUILD ────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        final allStrokes = [
          ..._strokes,
          if (_currentStroke.isNotEmpty) _currentStroke,
        ];

        return GestureDetector(
          onPanStart: _onPanStart,

          onPanUpdate: _onPanUpdate,

          onPanEnd: _onPanEnd,

          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),

            child: Stack(
              fit: StackFit.expand,

              children: [
                // ───────────── WORKSHEET BACKGROUND ─────────────
                CustomPaint(
                  size: size,
                  painter: GuidePainter(question: widget.question),
                ),

                // ───────────── IMAGE FROM DATABASE ──────────────
                if (widget.question.imageUrl != null &&
                    widget.question.imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),

                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.35,

                        child: Image.network(
                          'http://10.0.2.2:8080${widget.question.imageUrl!}',

                          fit: BoxFit.contain,

                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }

                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },

                          errorBuilder: (ctx, err, stack) {
                            return const Center(
                              child: Text(
                                'Image not found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                // ───────────── USER DRAWING ────────────────────
                CustomPaint(
                  size: size,

                  painter: UserDrawingPainter(
                    strokes: allStrokes,

                    strokeColor: AppColors.primary,

                    strokeWidth: 6,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
