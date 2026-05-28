// ════════════════════════════════════════════════════════════════════════════
// question_header.dart — prompt + "Tap to hear" button
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../../theme/theme.dart';

class QuestionHeader extends StatelessWidget {
  const QuestionHeader({
    super.key,
    required this.prompt,
    this.audioUrl,
    this.onPlayAudio,
  });

  final String prompt;
  final String? audioUrl;
  final VoidCallback? onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final isRtl = _hasArabic(prompt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prompt,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.3,
          ),
        ),
        if (audioUrl != null && audioUrl!.isNotEmpty) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onPlayAudio,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F6FE),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.volume_up_rounded,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Tap to hear',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _hasArabic(String s) => RegExp(r'[\u0600-\u06FF]').hasMatch(s);
}
