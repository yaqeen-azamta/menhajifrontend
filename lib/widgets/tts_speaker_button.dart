// ════════════════════════════════════════════════════════════════════════════
// tts_speaker_button.dart — Inline speaker button backed by Edge TTS.
//
// Tap → POST /api/audio/speak (backend) → play returned MP3.
// Shows a loading spinner while the backend is generating audio.
// Tap again while playing → stop.
// All failures are silent.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/theme.dart';

class TtsSpeakerButton extends StatefulWidget {
  const TtsSpeakerButton({
    super.key,
    required this.text,
    this.audioType = 'general',
    this.iconSize = 22,
  });

  /// Text to read aloud.
  final String text;

  /// Content-type hint for the backend voice style:
  /// welcome | motivation | hint | explanation | general
  final String audioType;

  final double iconSize;

  @override
  State<TtsSpeakerButton> createState() => _TtsSpeakerButtonState();
}

class _TtsSpeakerButtonState extends State<TtsSpeakerButton> {
  bool _loading = false; // waiting for backend response
  bool _playing = false; // audio is playing

  @override
  void dispose() {
    // Stop audio if this button is removed while playing.
    if (_playing || _loading) AudioService.instance.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return; // ignore taps while loading

    if (_playing) {
      await AudioService.instance.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }

    if (mounted) setState(() => _loading = true);

    await AudioService.instance.speak(
      widget.text,
      type: widget.audioType,
      onPlaybackEnd: () {
        if (mounted) setState(() => _playing = false);
      },
    );

    if (mounted) {
      setState(() {
        _loading = false;
        _playing = AudioService.instance.isPlaying;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hitSize = widget.iconSize + 14;

    // Loading: spinner while backend generates audio
    if (_loading) {
      return SizedBox(
        width: hitSize,
        height: hitSize,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.secondary,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: hitSize,
        height: hitSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _playing
              ? AppColors.secondary.withValues(alpha: 0.14)
              : Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Icon(
          _playing ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
          size: widget.iconSize,
          color: _playing ? AppColors.danger : AppColors.secondary,
        ),
      ),
    );
  }
}
