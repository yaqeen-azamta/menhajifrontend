// ════════════════════════════════════════════════════════════════════════════
// avatar_speech_bubble.dart — Prominent avatar + speech bubble for result/
//                             completion screens.
//
// Avatar circle (top) → triangle arrow → speech bubble (below).
// Speaker button calls backend Edge TTS via AudioService.
// autoRead: true → reads aloud automatically on first mount.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../services/audio_service.dart';
import '../../theme/theme.dart';

class AvatarSpeechBubble extends StatefulWidget {
  const AvatarSpeechBubble({
    super.key,
    required this.avatarEmoji,
    required this.message,
    this.autoRead = false,
    this.compact = false,
    this.audioType = 'motivation',
  });

  final String avatarEmoji;
  final String message;

  /// When true, reads aloud automatically on first mount.
  final bool autoRead;

  /// Reduces font/padding for dense layouts.
  final bool compact;

  /// Backend voice style: welcome | motivation | hint | explanation | general
  final String audioType;

  @override
  State<AvatarSpeechBubble> createState() => _AvatarSpeechBubbleState();
}

class _AvatarSpeechBubbleState extends State<AvatarSpeechBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  bool _loading = false;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    if (widget.autoRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startSpeech();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    if (_speaking || _loading) AudioService.instance.stop();
    super.dispose();
  }

  Future<void> _startSpeech() async {
    if (_loading) return;
    setState(() => _loading = true);
    await AudioService.instance.speak(
      widget.message,
      type: widget.audioType,
      onPlaybackEnd: () {
        if (mounted) setState(() => _speaking = false);
      },
    );
    if (mounted) {
      setState(() {
        _loading = false;
        _speaking = AudioService.instance.isPlaying;
      });
    }
  }

  Future<void> _toggleSpeech() async {
    if (_loading) return;
    if (_speaking) {
      await AudioService.instance.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    await _startSpeech();
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = widget.compact ? 48.0 : 64.0;
    final avatarFont = widget.compact ? 26.0 : 36.0;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Avatar circle ──────────────────────────────────
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: AppColors.gold, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.avatarEmoji,
                style: TextStyle(fontSize: avatarFont),
              ),
            ),

            // ── Downward arrow ─────────────────────────────────
            SizedBox(
              width: 22,
              height: 10,
              child: CustomPaint(painter: _DownArrowPainter()),
            ),

            // ── Speech bubble ──────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                widget.compact ? 12 : 16,
                widget.compact ? 10 : 13,
                widget.compact ? 8 : 10,
                widget.compact ? 10 : 13,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8DC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFFD580), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x16000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: widget.compact ? 13 : 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Speaker button
                  GestureDetector(
                    onTap: _loading ? null : _toggleSpeech,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _speaking
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : Colors.transparent,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _speaking
                                    ? Icons.stop_circle_outlined
                                    : Icons.volume_up_rounded,
                                size: 22,
                                color: _speaking
                                    ? AppColors.danger
                                    : AppColors.primary,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = const Color(0xFFFFF8DC)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFFFFD580)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cx = size.width / 2;
    final path = Path()
      ..moveTo(cx - 8, 0)
      ..lineTo(cx + 8, 0)
      ..lineTo(cx, size.height)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_DownArrowPainter _) => false;
}
