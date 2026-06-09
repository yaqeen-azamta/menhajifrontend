import 'package:flutter/material.dart';

import '../services/voice_service.dart';
import '../theme/theme.dart';

class MicButton extends StatefulWidget {
  const MicButton({super.key, required this.onTranscript});
  final void Function(String text) onTranscript;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  bool _recording = false;
  bool _busy = false;
  late final AnimationController _ctrl;

  // Use the singleton directly — no Riverpod needed
  final _voice = VoiceService.instance;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_recording) {
      setState(() => _busy = true);
      final text = await _voice.stopAndTranscribe();
      setState(() {
        _recording = false;
        _busy = false;
      });
      widget.onTranscript(text ?? '');
    } else {
      setState(() => _busy = true);
      final ok = await _voice.startRecording();
      setState(() {
        _busy = false;
        _recording = ok;
      });
      if (!ok) widget.onTranscript('__no_permission__');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = _recording
        ? Tween<double>(begin: 1.0, end: 1.18).animate(_ctrl)
        : const AlwaysStoppedAnimation<double>(1.0);
    final bg = _recording ? AppColors.danger : AppColors.secondary;
    final shadow = _recording
        ? AppColors.dangerShadow
        : AppColors.secondaryShadow;

    return Column(
      children: [
        GestureDetector(
          onTap: _busy ? null : _toggle,
          child: AnimatedBuilder(
            animation: scale,
            builder: (ctx, child) => Transform.scale(
              scale: scale.value,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border(bottom: BorderSide(color: shadow, width: 5)),
                  boxShadow: [
                    BoxShadow(
                      color: shadow.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _recording ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _busy
              ? 'Listening...'
              : _recording
              ? 'Tap to stop'
              : 'Tap and speak',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
