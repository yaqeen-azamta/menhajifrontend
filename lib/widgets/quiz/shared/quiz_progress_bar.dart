// ════════════════════════════════════════════════════════════════════════════
// quiz_progress_bar.dart — top bar with close + progress + hearts
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../../theme/theme.dart';

class QuizProgressBar extends StatelessWidget {
  const QuizProgressBar({
    super.key,
    required this.progress,
    required this.hearts,
    required this.onClose,
  });

  /// 0.0 → 1.0
  final double progress;
  final int hearts;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 26),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (ctx, v, child) => LinearProgressIndicator(
                  value: v,
                  minHeight: 14,
                  backgroundColor: const Color(0xFFE8DCC8),
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEB),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, color: AppColors.danger, size: 18),
                const SizedBox(width: 4),
                Text(
                  '$hearts',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
