// ════════════════════════════════════════════════════════════════════════════
// listen_and_choose — prominent play button at top, options below.
// Audio replays on tap. Student picks the option that matches what they heard.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../models/question_model.dart';
import '../../../services/voice_service.dart';
import '../../../theme/theme.dart';
import '../quiz/question_callback.dart';
class ListenAndChooseQuestion extends StatefulWidget {
  const ListenAndChooseQuestion({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.locked,
  });

  final Question question;
  final OnAnswerSubmitted onAnswer;
  final bool locked;

  @override
  State<ListenAndChooseQuestion> createState() =>
      _ListenAndChooseQuestionState();
}

class _ListenAndChooseQuestionState extends State<ListenAndChooseQuestion>
    with SingleTickerProviderStateMixin {
  int? _selected;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.95,
    upperBound: 1.05,
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    // Auto-play once on entry
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final url = widget.question.audioUrl;
    if (url != null && url.isNotEmpty) {
      await VoiceService.instance.playUrl(url);
    }
  }

  void _select(int i) {
    setState(() => _selected = i);
    widget.onAnswer(SubmittedAnswer(answer: widget.question.options[i].text));
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'LISTEN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.secondary,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            q.questionText.isEmpty ? 'What did you hear?' : q.questionText,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 28),

          // Big play button
          GestureDetector(
            onTap: _play,
            child: ScaleTransition(
              scale: _pulse,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.secondaryShadow,
                      width: 6,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondaryShadow.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap to replay',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 28),

          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _select(i),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _selected == i
                          ? AppColors.secondary
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                    color: _selected == i
                        ? AppColors.secondary.withValues(alpha: 0.1)
                        : Colors.white,
                  ),
                  child: Column(
                    children: [
                      // IMAGE
                      if (q.options[i].imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            q.options[i].imageUrl,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) =>
                                const SizedBox.shrink(),
                          ),
                        ),

                      // TEXT
                      if (q.options[i].text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            q.options[i].text,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
