// ════════════════════════════════════════════════════════════════════════════
// coloring_question.dart
//
// COLORING — tap-to-color question.
// No free-hand drawing. No canvas painting.
//
// Flow:
//   1. Student picks a color from the palette (red / green / blue / yellow).
//   2. Student taps individual object tiles to apply the selected color.
//   3. Tapping a colored tile again removes the color (toggle/reset).
//   4. A progress bar shows how many required colorings are done.
//   5. When ALL objects have the required count colored correctly the Submit
//      button activates.  Student can also submit a partial answer.
//
// Answer contract:
//   SubmittedAnswer.answer = JSON string
//     [{"objectId":"tomato.png","color":"red","count":2}, ...]
//   SubmittedAnswer.structured = {'selections': [...same list...]}
// ════════════════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../../../theme/theme.dart';
import '../quiz/question_callback.dart';
import '../quiz/shared/question_header.dart';

// ── Palette definition ────────────────────────────────────────────────────────

class _PaletteColor {
  final String name;
  final Color color;
  final Color border;

  const _PaletteColor(this.name, this.color, this.border);
}

const _palette = [
  _PaletteColor('red', Color(0xFFFF4B4B), Color(0xFFCC2929)),
  _PaletteColor('green', Color(0xFF58CC02), Color(0xFF3A9900)),
  _PaletteColor('blue', Color(0xFF1CB0F6), Color(0xFF0A8AC4)),
  _PaletteColor('yellow', Color(0xFFFFC800), Color(0xFFD4A400)),
];

Color _colorForName(String name) {
  final match = _palette.where(
    (p) => p.name.toLowerCase() == name.toLowerCase(),
  );
  if (match.isNotEmpty) return match.first.color;
  // Fallback: try to parse as hex (#RRGGBB)
  if (name.startsWith('#') && name.length == 7) {
    try {
      return Color(int.parse('FF${name.substring(1)}', radix: 16));
    } catch (_) {}
  }
  return Colors.grey;
}

// ─────────────────────────────────────────────────────────────────────────────

class ColoringQuestion extends StatefulWidget {
  const ColoringQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<ColoringQuestion> createState() => _ColoringQuestionState();
}

class _ColoringQuestionState extends State<ColoringQuestion> {
  // Currently selected palette color name (null = none selected yet).
  String? _selectedColor;

  // objectImage → list of per-tile color names (null = uncolored).
  // Length == coloringObject.totalCount for that group.
  late final Map<String, List<String?>> _tileColors;

  @override
  void initState() {
    super.initState();
    _tileColors = {
      for (final obj in widget.question.coloringObjects)
        obj.image: List<String?>.filled(obj.totalCount, null),
    };
  }

  // ── Interaction ───────────────────────────────────────────────────────────

  void _selectPalette(String colorName) {
    if (widget.locked) return;
    setState(() => _selectedColor = colorName);
  }

  void _tapTile(String objectImage, int tileIndex) {
    if (widget.locked) return;
    if (_selectedColor == null) return;

    setState(() {
      final tiles = _tileColors[objectImage]!;
      if (tiles[tileIndex] == _selectedColor) {
        // Toggle off — remove the color from this tile.
        tiles[tileIndex] = null;
      } else {
        tiles[tileIndex] = _selectedColor;
      }
    });
  }

  void _resetAll() {
    if (widget.locked) return;
    setState(() {
      for (final key in _tileColors.keys) {
        final len = _tileColors[key]!.length;
        _tileColors[key] = List<String?>.filled(len, null);
      }
    });
  }

  void _submit() {
    final selections = widget.question.coloringObjects.map((obj) {
      final tiles = _tileColors[obj.image] ?? [];
      final colorName = obj.targetColor;
      final count = tiles.where((c) => c == colorName).length;
      return {'objectId': obj.image, 'color': colorName, 'count': count};
    }).toList();

    final answerJson = jsonEncode(selections);
    widget.onAnswer(
      SubmittedAnswer(
        answer: answerJson,
        structured: {'selections': selections},
      ),
    );
  }

  // ── Progress helpers ──────────────────────────────────────────────────────

  /// How many object groups are fully completed (correct color × required count).
  int get _completedGroups {
    int done = 0;
    for (final obj in widget.question.coloringObjects) {
      final tiles = _tileColors[obj.image] ?? [];
      final count = tiles.where((c) => c == obj.targetColor).length;
      if (count == obj.requiredCount) done++;
    }
    return done;
  }

  int get _totalGroups => widget.question.coloringObjects.length;

  bool get _allDone => _completedGroups == _totalGroups && _totalGroups > 0;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final q = widget.question;

    if (q.coloringObjects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          q.questionText.isNotEmpty ? q.questionText : 'Coloring question',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestionHeader(prompt: q.questionText, audioUrl: q.audioUrl),
          const SizedBox(height: 20),

          // ── Colour palette ──────────────────────────────────────
          _buildPalette(),
          const SizedBox(height: 6),
          if (_selectedColor == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Pick a color first',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          const SizedBox(height: 16),

          // ── Object groups ───────────────────────────────────────
          ...q.coloringObjects.map((obj) => _buildObjectGroup(obj)),

          const SizedBox(height: 20),

          // ── Progress bar ────────────────────────────────────────
          _buildProgress(),
          const SizedBox(height: 20),

          // ── Action row: Reset + Submit ──────────────────────────
          Row(
            children: [
              _buildResetButton(),
              const SizedBox(width: 12),
              Expanded(child: _buildSubmitButton()),
            ],
          ),
        ],
      ),
    );
  }

  // ── Palette ───────────────────────────────────────────────────────────────

  Widget _buildPalette() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _palette.map((p) {
        final isActive = _selectedColor == p.name;
        return GestureDetector(
          onTap: () => _selectPalette(p.name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: p.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? Colors.black87 : p.border,
                width: isActive ? 3.5 : 2,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: p.color.withValues(alpha: 0.5),
                        blurRadius: 14,
                        spreadRadius: 3,
                      ),
                    ]
                  : [],
            ),
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 22)
                : null,
          ),
        );
      }).toList(),
    );
  }

  // ── Object group ──────────────────────────────────────────────────────────

  Widget _buildObjectGroup(ColoringObject obj) {
    final tiles = _tileColors[obj.image] ?? [];
    final target = obj.targetColor;
    final colored = tiles.where((c) => c == target).length;
    final done = colored == obj.requiredCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: done
              ? _colorForName(target).withValues(alpha: 0.7)
              : const Color(0xFFE8E8E8),
          width: done ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label: "Color 2 red" with a swatch
          Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: _colorForName(target),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12, width: 1),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Color ${'${obj.requiredCount}'} $target',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // Mini progress counter
              Text(
                '$colored / ${obj.requiredCount}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: done ? _colorForName(target) : AppColors.textSecondary,
                ),
              ),
              if (done) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: _colorForName(target),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Tile grid
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(obj.totalCount, (i) {
              return _ObjectTile(
                imageUrl: obj.image,
                appliedColor: tiles[i],
                targetColor: target,
                locked: widget.locked,
                onTap: () => _tapTile(obj.image, i),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Progress bar ──────────────────────────────────────────────────────────

  Widget _buildProgress() {
    final fraction = _totalGroups > 0 ? _completedGroups / _totalGroups : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_completedGroups / $_totalGroups groups complete',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _allDone ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            backgroundColor: const Color(0xFFE8E8E8),
            valueColor: AlwaysStoppedAnimation<Color>(
              _allDone ? AppColors.primary : AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }

  // ── Buttons ───────────────────────────────────────────────────────────────

  Widget _buildResetButton() {
    return GestureDetector(
      onTap: widget.locked ? null : _resetAll,
      child: Container(
        height: 54,
        width: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.locked
                ? AppColors.lockBorder
                : const Color(0xFFE0E0E0),
            width: 2,
          ),
        ),
        child: Icon(
          Icons.refresh_rounded,
          color: widget.locked ? AppColors.lockBorder : AppColors.textSecondary,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final ready = !widget.locked;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: _allDone && ready ? AppColors.primary : AppColors.secondary,
        boxShadow: ready
            ? [
                BoxShadow(
                  color:
                      (_allDone
                              ? AppColors.primaryShadow
                              : AppColors.secondaryShadow)
                          .withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: ready ? _submit : null,
          child: const Center(
            child: Text(
              'Submit',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ObjectTile — single tappable object image.
// ─────────────────────────────────────────────────────────────────────────────

class _ObjectTile extends StatelessWidget {
  const _ObjectTile({
    required this.imageUrl,
    required this.appliedColor,
    required this.targetColor,
    required this.locked,
    required this.onTap,
  });

  final String imageUrl;
  final String? appliedColor;
  final String targetColor;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isColored = appliedColor != null;
    final tileColor = isColored ? _colorForName(appliedColor!) : null;

    return GestureDetector(
      onTap: locked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: isColored
              ? tileColor!.withValues(alpha: 0.15)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isColored ? tileColor! : const Color(0xFFDDDDDD),
            width: isColored ? 2.5 : 1.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Object image — greyscale when uncolored, full color when colored.
            ColorFiltered(
              colorFilter: isColored
                  ? ColorFilter.mode(
                      tileColor!.withValues(alpha: 0.35),
                      BlendMode.srcATop,
                    )
                  : const ColorFilter.matrix([
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Builder(
                  builder: (context) {
                    final resolvedUrl = imageUrl.startsWith('http')
                        ? imageUrl
                        : 'http://10.0.2.2:8080$imageUrl';

                    print('COLOR IMAGE = $resolvedUrl');

                    return Image.network(
                      resolvedUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => Icon(
                        Icons.circle_outlined,
                        size: 32,
                        color: isColored ? tileColor : Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Small color dot overlay when colored.
            if (isColored)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tileColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
