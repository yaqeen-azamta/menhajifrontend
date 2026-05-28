// ════════════════════════════════════════════════════════════════════════════
// feedback_panel.dart — bottom panel after answer submission
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../../l10n/app_strings.dart';
import '../../../../theme/theme.dart';
import '../../fat_button.dart';

class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.isCorrect,
    required this.feedback,
    required this.correctAnswer,
    required this.isLast,
    required this.onContinue,
    this.submitting = false,
  });

  final bool isCorrect;
  final String? feedback;
  final String? correctAnswer;
  final bool isLast;
  final VoidCallback onContinue;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final bg = isCorrect ? const Color(0xFFFFF8E6) : const Color(0xFFFFE8E8);
    final border = isCorrect
        ? const Color(0xFFFFD580)
        : const Color(0xFFFFB3B3);
    final accent = isCorrect ? AppColors.primary : AppColors.danger;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 60),
        child: Opacity(opacity: v, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: border, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isCorrect ? '🎉' : '😅',
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 8),
                Text(
                  isCorrect ? AppStrings.feedbackCorrect : AppStrings.feedbackWrong,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ],
            ),
            if (feedback != null && feedback!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                feedback!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (!isCorrect &&
                correctAnswer != null &&
                correctAnswer!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                AppStrings.feedbackCorrectAnswer(correctAnswer!),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FatButton(
              label: isLast ? AppStrings.finish : AppStrings.continueBtn,
              color: isCorrect ? FatColor.primary : FatColor.danger,
              loading: submitting,
              onPressed: onContinue,
            ),
          ],
        ),
      ),
    );
  }
}
