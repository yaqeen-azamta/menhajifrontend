import 'package:flutter/material.dart';

import '../models/tracing_result.dart';

/// Shown after the user taps "Check My Work".
/// Displays accuracy %, a star rating, feedback text, and Retry / Next actions.
class ResultDialog extends StatelessWidget {
  final TracingResult result;
  final VoidCallback onRetry;
  final VoidCallback onNext;

  const ResultDialog({
    super.key,
    required this.result,
    required this.onRetry,
    required this.onNext,
  });

  Color get _accent =>
      result.isCorrect ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji
            Text(
              result.isCorrect ? '🎉' : '💪',
              style: const TextStyle(fontSize: 60),
            ),
            const SizedBox(height: 14),

            // Accuracy percentage
            Text(
              result.accuracyPercent,
              style: TextStyle(
                fontSize: 62,
                fontWeight: FontWeight.w900,
                color: _accent,
                height: 1,
              ),
            ),
            const SizedBox(height: 10),

            // Star row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Icon(
                  i < result.starRating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: const Color(0xFFFFA000),
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Feedback message
            Text(
              result.isCorrect
                  ? 'Great job! Keep it up!'
                  : 'Almost there — try again!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // Detail row
            Text(
              'Coverage ${(result.coverage * 100).round()}%  •  '
              'Precision ${(result.precision * 100).round()}%  •  '
              'Score ${result.score}/100',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1565C0)),
                      foregroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Next',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}