// ════════════════════════════════════════════════════════════════════════════
// drag_drop_question — student drags tokens into named target columns.
//
// Answer format sent to backend: "target1=token1,target1=token2,target2=token3"
//
// tokenStatus  — passed from parent after a wrong-answer check.
//                Maps token → isCorrect so chips show green / red borders.
// onInteraction — called on every drag so parent can clear the tokenStatus
//                 highlight state once the student starts fixing their answer.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../../../theme/theme.dart';
import '../fat_button.dart';
import '../quiz/question_callback.dart';
import '../quiz/shared/question_header.dart';

// ─── Payload carried by every Draggable so drop targets know origin ──────────

class _DragPayload {
  final String token;
  final String? fromTarget; // null  → dragging from the word bank
  const _DragPayload({required this.token, this.fromTarget});
}

// ─── Public widget ────────────────────────────────────────────────────────────

class DragDropQuestion extends StatefulWidget {
  const DragDropQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
    this.tokenStatus,
    this.onInteraction,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  /// token → isCorrect, populated by parent after a wrong-answer check.
  /// null means "not yet checked" — no colour highlights.
  final Map<String, bool>? tokenStatus;

  /// Fired on every drag action so the parent can clear stale highlights.
  final VoidCallback? onInteraction;

  @override
  State<DragDropQuestion> createState() => _DragDropQuestionState();
}

class _DragDropQuestionState extends State<DragDropQuestion> {
  /// targetLabel → ordered list of tokens dropped into that target.
  late final Map<String, List<String>> _drops = {
    for (final t in widget.question.targets) t: <String>[],
  };

  /// Tokens not yet placed in any target.
  late final List<String> _bank = List.from(widget.question.tokens);

  // ── Drag helpers ────────────────────────────────────────────────────────

  void _moveToTarget(String token, String? fromTarget, String toTarget) {
    if (widget.locked) return;
    if (fromTarget == toTarget) return;
    widget.onInteraction?.call();
    setState(() {
      if (fromTarget != null) {
        _drops[fromTarget]?.remove(token);
      } else {
        _bank.remove(token);
      }
      _drops[toTarget]?.add(token);
    });
  }

  void _returnToBank(String token, String fromTarget) {
    if (widget.locked) return;
    widget.onInteraction?.call();
    setState(() {
      _drops[fromTarget]?.remove(token);
      _bank.add(token);
    });
  }

  // ── Submission ──────────────────────────────────────────────────────────

  bool get _canSubmit => _bank.isEmpty && !widget.locked;

  void _submit() {
    final pairs = <String>[];
    _drops.forEach((target, tokens) {
      for (final t in tokens) {
        pairs.add('$target=$t');
      }
    });
    widget.onAnswer(
      SubmittedAnswer(answer: pairs.join(','), structured: {'drops': _drops}),
    );
  }

  // ── Chip colour helpers (Task 5) ────────────────────────────────────────

  Color _chipBorder(String token, {Color? fallback}) {
    final s = widget.tokenStatus;
    if (s == null) return fallback ?? const Color(0xFFCCCCCC);
    final ok = s[token];
    if (ok == null) return fallback ?? const Color(0xFFCCCCCC);
    return ok ? const Color(0xFF2E7D32) : AppColors.danger;
  }

  Color _chipBackground(String token, {Color? fallback}) {
    final s = widget.tokenStatus;
    if (s == null) return fallback ?? Colors.white;
    final ok = s[token];
    if (ok == null) return fallback ?? Colors.white;
    return ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuestionHeader(prompt: q.questionText, audioUrl: q.audioUrl),
            const SizedBox(height: 20),

            // ── Target zones — vertical, one per column ────────────────
            ...q.targets.map(_buildTargetZone),

            const SizedBox(height: 16),

            // ── Word-bank label ────────────────────────────────────────
            const Text(
              'بنك الكلمات',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            // ── Draggable word bank ────────────────────────────────────
            DragTarget<_DragPayload>(
              onWillAcceptWithDetails: (d) =>
                  !widget.locked && d.data.fromTarget != null,
              onAcceptWithDetails: (d) =>
                  _returnToBank(d.data.token, d.data.fromTarget!),
              builder: (_, candidates, _) {
                final hovering = candidates.isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hovering
                        ? AppColors.primary.withValues(alpha: 0.07)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: hovering
                          ? AppColors.primary
                          : const Color(0xFFE0E0E0),
                      width: 2,
                    ),
                  ),
                  child: _bank.isEmpty
                      ? const Center(
                          child: Text(
                            'تم وضع جميع الكلمات ✓',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: _bank.map(_buildBankChip).toList(),
                        ),
                );
              },
            ),

            const SizedBox(height: 24),

            FatButton(
              label: 'تحقق من الإجابة',
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Target zone card ─────────────────────────────────────────────────────

  Widget _buildTargetZone(String target) {
    final tokens = _drops[target] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column label
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              target,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Drop zone
          DragTarget<_DragPayload>(
            onWillAcceptWithDetails: (d) =>
                !widget.locked && d.data.fromTarget != target,
            onAcceptWithDetails: (d) =>
                _moveToTarget(d.data.token, d.data.fromTarget, target),
            builder: (_, candidates, _) {
              final hovering = candidates.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hovering
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: hovering
                        ? AppColors.primary
                        : const Color(0xFFE0E0E0),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: tokens.isEmpty
                    ? Center(
                        child: Text(
                          hovering ? 'أفلت هنا' : 'اسحب الكلمة هنا',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.start,
                        children: tokens
                            .map((t) => _buildZoneChip(t, target))
                            .toList(),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Chip: inside a drop zone ─────────────────────────────────────────────

  Widget _buildZoneChip(String token, String fromTarget) {
    return Draggable<_DragPayload>(
      data: _DragPayload(token: token, fromTarget: fromTarget),
      feedback: Material(
        color: Colors.transparent,
        child: _Chip(
          token: token,
          borderColor: AppColors.primary,
          bgColor: AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _Chip(token: token),
      ),
      child: GestureDetector(
        onTap: widget.locked ? null : () => _returnToBank(token, fromTarget),
        child: _Chip(
          token: token,
          borderColor: _chipBorder(token),
          bgColor: _chipBackground(token),
        ),
      ),
    );
  }

  // ── Chip: inside the word bank ───────────────────────────────────────────

  Widget _buildBankChip(String token) {
    return Draggable<_DragPayload>(
      data: _DragPayload(token: token),
      feedback: Material(
        color: Colors.transparent,
        child: _Chip(
          token: token,
          borderColor: AppColors.secondary,
          bgColor: AppColors.secondary.withValues(alpha: 0.12),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _Chip(token: token)),
      child: _Chip(token: token),
    );
  }
}

// ─── Reusable chip ────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.token,
    this.borderColor,
    this.bgColor,
  });

  final String token;
  final Color? borderColor;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? const Color(0xFFCCCCCC);
    final bg = bgColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 2),
        boxShadow: [
          BoxShadow(
            color: border.withValues(alpha: 0.22),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        token,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
      ),
    );
  }
}
