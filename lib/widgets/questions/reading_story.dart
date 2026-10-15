// ════════════════════════════════════════════════════════════════════════════
// reading_story.dart — Story display widget for READING questions.
//
// Shows: story illustration → title → text card → big TTS play button.
// Plays the story via the backend Edge TTS (AudioService) or a pre-recorded
// audio URL when provided. Does NOT record the user — this is a content
// widget, not a pronunciation assessment.
//
// Usage:
//   ReadingStory(
//     title: q.questionText,
//     storyText: q.correctAnswer ?? q.questionText,
//     imageUrl: '$kBaseUrl${q.imageUrl}',   // pass null when not available
//     audioUrl: q.audioUrl,                 // optional; falls back to TTS
//   )
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../services/audio_service.dart';
import '../../theme/theme.dart';

class ReadingStory extends StatefulWidget {
  const ReadingStory({
    super.key,
    required this.title,
    required this.storyText,
    this.imageUrl,
    this.audioUrl,
  });

  final String title;
  final String storyText;
  final String? imageUrl;
  final String? audioUrl;

  @override
  State<ReadingStory> createState() => _ReadingStoryState();
}

class _ReadingStoryState extends State<ReadingStory>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  bool _isLoading = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.94,
    upperBound: 1.06,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    AudioService.instance.stop();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isLoading) return;

    if (_isPlaying) {
      await AudioService.instance.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    final audioUrl = widget.audioUrl;
    if (audioUrl != null && audioUrl.isNotEmpty) {
      await AudioService.instance.playUrl(audioUrl);
      if (mounted) setState(() { _isLoading = false; _isPlaying = true; });
    } else {
      await AudioService.instance.speak(
        widget.storyText,
        type: 'explanation',
        onPlaybackEnd: () {
          if (mounted) setState(() => _isPlaying = false);
        },
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = AudioService.instance.isPlaying;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Story illustration ──────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: hasImage
              ? Image.network(
                  widget.imageUrl!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _StoryPlaceholder(),
                )
              : const _StoryPlaceholder(),
        ),
        const SizedBox(height: 20),

        // ── Title ───────────────────────────────────────────────────────────
        Text(
          widget.title,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),

        // ── Story text card ─────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                offset: Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Text(
            widget.storyText,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.85,
            ),
          ),
        ),
        const SizedBox(height: 36),

        // ── Play / Stop button ──────────────────────────────────────────────
        Center(
          child: GestureDetector(
            onTap: _togglePlay,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: _isPlaying ? _pulse.value : 1.0,
                child: child,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  color: _isLoading
                      ? AppColors.secondary.withValues(alpha: 0.55)
                      : _isPlaying
                          ? AppColors.secondary
                          : AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border(
                    bottom: BorderSide(
                      color: _isPlaying
                          ? AppColors.secondaryShadow
                          : AppColors.primaryShadow,
                      width: 5,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isPlaying
                              ? AppColors.secondary
                              : AppColors.primary)
                          .withValues(alpha: 0.34),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3.5,
                          ),
                        ),
                      )
                    : Icon(
                        _isPlaying
                            ? Icons.stop_rounded
                            : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── State label ─────────────────────────────────────────────────────
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _isLoading
                  ? 'جارٍ التحميل...'
                  : _isPlaying
                      ? 'جارٍ القراءة... (اضغط للإيقاف)'
                      : 'اضغط للاستماع 🔊',
              key: ValueKey(_isLoading ? 0 : _isPlaying ? 1 : 2),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _isPlaying
                    ? AppColors.secondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Warm parchment placeholder shown when no image URL is provided ───────────

class _StoryPlaceholder extends StatelessWidget {
  const _StoryPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5EDD8), Color(0xFFEDE0C4)],
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('📖', style: TextStyle(fontSize: 72)),
          SizedBox(height: 8),
          Text(
            'قصة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
