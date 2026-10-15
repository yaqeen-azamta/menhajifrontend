// ════════════════════════════════════════════════════════════════════════════
// matching_question.dart
//
// MATCHING — two columns of cards (left and right).
// Interaction:
//   1. Tap a left card  → it becomes the "pending" item.
//   2. Tap a right card → the pair is created and both cards turn coloured.
//   3. Tap an already-matched card → the pair is removed (re-match allowed).
//   4. When every left item has a match, the Submit button becomes active.
//   5. Student taps Submit → answer is sent as "leftId1=rightId1,…".
//
// Supports all combinations: text↔text, text↔image, image↔image, image↔text.
//
// Answer contract:
//   SubmittedAnswer.answer  = "leftId1=rightId1,leftId2=rightId2,…"
//   SubmittedAnswer.structured = {'matches': {leftId: rightId, …}}
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../../../theme/theme.dart';
import '../quiz/question_callback.dart';
import '../quiz/shared/question_header.dart';

class MatchingQuestion extends StatefulWidget {
  const MatchingQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<MatchingQuestion> createState() => _MatchingQuestionState();
}

class _MatchingQuestionState extends State<MatchingQuestion> {
  // leftId → rightId
  final Map<String, String> _matches = {};

  // The left card currently waiting for a right partner (highlighted in blue).
  String? _pendingLeftId;

  // Colour palette — one colour per pair index so matches are visually distinct.
  static const _palette = [
    Color(0xFF58CC02),
    Color(0xFF1CB0F6),
    Color(0xFFFF9600),
    Color(0xFFCE82FF),
    Color(0xFFFF4B4B),
    Color(0xFFFFC800),
  ];

  // ── Tap handlers ─────────────────────────────────────────────────────────

  void _tapLeft(String id) {
    if (widget.locked) return;

    if (_isLeftMatched(id)) {
      // Already matched → remove that pair so the user can re-match.
      setState(() {
        _matches.remove(id);
        _pendingLeftId = id; // keep it pending so next right-tap pairs it
      });
      return;
    }

    setState(() => _pendingLeftId = id);
  }

  void _tapRight(String id) {
    if (widget.locked) return;
    if (_pendingLeftId == null) return;

    if (_isRightMatched(id)) {
      // Remove the existing pair that uses this right item.
      setState(() {
        _matches.removeWhere((k, v) => v == id);
      });
    }

    setState(() {
      _matches[_pendingLeftId!] = id;
      _pendingLeftId = null;
    });
  }

  void _submit() {
    if (!_allMatched) return;
    final payload = _matches.entries.map((e) => '${e.key}=${e.value}').join(',');
    widget.onAnswer(
      SubmittedAnswer(
        answer: payload,
        structured: {'matches': Map<String, String>.from(_matches)},
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isLeftMatched(String id)  => _matches.containsKey(id);
  bool _isRightMatched(String id) => _matches.containsValue(id);

  bool get _allMatched =>
      _matches.length == widget.question.leftPairs.length &&
      widget.question.leftPairs.isNotEmpty;

  Color? _colorForLeft(String leftId) {
    final idx = _matches.keys.toList().indexOf(leftId);
    return idx >= 0 ? _palette[idx % _palette.length] : null;
  }

  Color? _colorForRight(String rightId) {
    String? leftId;
    _matches.forEach((k, v) {
      if (v == rightId) leftId = k;
    });
    return leftId == null ? null : _colorForLeft(leftId!);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final q    = widget.question;
    final left  = q.leftPairs;
    final right = q.rightPairs;

    if (left.isEmpty || right.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          q.questionText.isNotEmpty ? q.questionText : 'Matching question',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestionHeader(
            prompt: q.questionText.isNotEmpty
                ? q.questionText
                : 'Match the pairs',
            audioUrl: q.audioUrl,
          ),
          const SizedBox(height: 8),
          _buildProgressHint(),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildColumn(left,  isLeft: true)),
              const SizedBox(width: 14),
              Expanded(child: _buildColumn(right, isLeft: false)),
            ],
          ),
          const SizedBox(height: 24),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildProgressHint() {
    final matched = _matches.length;
    final total   = widget.question.leftPairs.length;
    return Text(
      '$matched / $total matched',
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _allMatched ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildColumn(List<MatchPair> pairs, {required bool isLeft}) {
    return Column(
      children: pairs.map((pair) {
        final id      = pair.id;
        final matched = isLeft ? _isLeftMatched(id) : _isRightMatched(id);
        final pending = isLeft && _pendingLeftId == id;
        final color   = isLeft ? _colorForLeft(id) : _colorForRight(id);

        return _MatchCard(
          pair: pair,
          isSelected: pending,
          isMatched: matched,
          pairColor: color,
          onTap: isLeft ? () => _tapLeft(id) : () => _tapRight(id),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    final ready = _allMatched && !widget.locked;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: ready ? AppColors.primary : AppColors.lockBg,
          boxShadow: ready
              ? [
                  BoxShadow(
                    color: AppColors.primaryShadow.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: ready ? _submit : null,
            child: Center(
              child: Text(
                'Submit',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: ready ? Colors.white : AppColors.lockBorder,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MatchCard — reusable card for a single left or right item.
// ─────────────────────────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.pair,
    required this.isSelected,
    required this.isMatched,
    required this.onTap,
    this.pairColor,
  });

  final MatchPair pair;
  final bool isSelected;
  final bool isMatched;
  final Color? pairColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent   = pairColor ?? AppColors.secondary;
    final hasImage = pair.imageUrl != null && pair.imageUrl!.isNotEmpty;
    final hasText  = pair.text != null && pair.text!.isNotEmpty;

    final bgColor     = isMatched
        ? accent.withValues(alpha: 0.12)
        : isSelected
            ? const Color(0xFFE6F6FE)
            : Colors.white;
    final borderColor = isMatched
        ? accent
        : isSelected
            ? AppColors.secondary
            : const Color(0xFFE5E5E5);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 2.5),
            boxShadow: [
              if (isSelected || isMatched)
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasImage)
                Image.network(
                  pair.imageUrl!,
                  height: 80,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 80,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                  errorBuilder: (ctx, err, stack) => const SizedBox(
                    height: 80,
                    child: Icon(Icons.broken_image_outlined,
                        size: 40, color: Color(0xFFCCCCCC)),
                  ),
                ),
              if (hasText) ...[
                if (hasImage) const SizedBox(height: 6),
                Text(
                  pair.text!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isMatched ? accent : AppColors.textPrimary,
                  ),
                ),
              ],
              if (isMatched && hasImage) ...[
                const SizedBox(height: 4),
                Icon(Icons.check_circle_rounded, color: accent, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
