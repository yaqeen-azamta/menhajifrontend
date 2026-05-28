// ════════════════════════════════════════════════════════════════════════════
// image_match_question — two columns of cards (left and right).
// Tap one card on each side → they get linked. Repeat until all matched.
// When everything is paired → auto-submit a serialized mapping.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../../../theme/theme.dart';
import '../quiz/question_callback.dart';
import '../quiz/shared/question_header.dart';

class ImageMatchQuestion extends StatefulWidget {
  const ImageMatchQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<ImageMatchQuestion> createState() => _ImageMatchQuestionState();
}

class _ImageMatchQuestionState extends State<ImageMatchQuestion> {
  /// leftId → rightId
  final Map<String, String> _matches = {};
  String? _pendingLeft;
  String? _pendingRight;

  static const _palette = [
    Color(0xFF58CC02),
    Color(0xFF1CB0F6),
    Color(0xFFFF9600),
    Color(0xFFCE82FF),
    Color(0xFFFF4B4B),
    Color(0xFFFFC800),
  ];

  void _tapLeft(String id) {
    if (widget.locked) return;
    if (_isLeftMatched(id)) return;
    setState(() => _pendingLeft = id);
    _tryPair();
  }

  void _tapRight(String id) {
    if (widget.locked) return;
    if (_isRightMatched(id)) return;
    setState(() => _pendingRight = id);
    _tryPair();
  }

  void _tryPair() {
    if (_pendingLeft != null && _pendingRight != null) {
      setState(() {
        _matches[_pendingLeft!] = _pendingRight!;
        _pendingLeft = null;
        _pendingRight = null;
      });

      // All matched → auto-submit
      if (_matches.length == widget.question.leftPairs.length) {
        final payload = _matches.entries
            .map((e) => '${e.key}=${e.value}')
            .join(',');
        widget.onAnswer(
          SubmittedAnswer(answer: payload, structured: {'matches': _matches}),
        );
      }
    }
  }

  bool _isLeftMatched(String id) => _matches.containsKey(id);
  bool _isRightMatched(String id) => _matches.containsValue(id);

  /// Returns the color index used for a given pair (consistent left/right).
  int? _colorIndexFor(String leftId) {
    final keys = _matches.keys.toList();
    final idx = keys.indexOf(leftId);
    return idx >= 0 ? idx : null;
  }

  int? _colorIndexForRight(String rightId) {
    String? leftId;
    _matches.forEach((k, v) {
      if (v == rightId) leftId = k;
    });
    return leftId == null ? null : _colorIndexFor(leftId!);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final left = q.leftPairs;
    final right = q.rightPairs;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestionHeader(
            prompt: q.questionText.isNotEmpty
                ? q.questionText
                : 'Tap the matching pairs',
            audioUrl: q.audioUrl,
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: left.asMap().entries.map((e) {
                    final colorIdx = _colorIndexFor(e.value.id);
                    return _MatchCard(
                      pair: e.value,
                      isSelected: _pendingLeft == e.value.id,
                      isMatched: _isLeftMatched(e.value.id),
                      color: colorIdx == null
                          ? null
                          : _palette[colorIdx % _palette.length],
                      onTap: () => _tapLeft(e.value.id),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: right.asMap().entries.map((e) {
                    final colorIdx = _colorIndexForRight(e.value.id);
                    return _MatchCard(
                      pair: e.value,
                      isSelected: _pendingRight == e.value.id,
                      isMatched: _isRightMatched(e.value.id),
                      color: colorIdx == null
                          ? null
                          : _palette[colorIdx % _palette.length],
                      onTap: () => _tapRight(e.value.id),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.pair,
    required this.isSelected,
    required this.isMatched,
    required this.onTap,
    this.color,
  });

  final MatchPair pair;
  final bool isSelected, isMatched;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = color ?? AppColors.secondary;

    return GestureDetector(
      onTap: isMatched ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMatched
              ? highlight.withValues(alpha: 0.15)
              : isSelected
              ? const Color(0xFFE6F6FE)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMatched
                ? highlight
                : isSelected
                ? AppColors.secondary
                : const Color(0xFFE5E5E5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isMatched ? highlight : const Color(0xFFE5E5E5),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            if (pair.imageUrl != null && pair.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  pair.imageUrl!,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => const SizedBox(height: 70),
                ),
              ),
            if (pair.text != null && pair.text!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  pair.text!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
