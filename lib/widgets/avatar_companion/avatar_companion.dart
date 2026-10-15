// ════════════════════════════════════════════════════════════════════════════
// avatar_companion.dart — Reusable AvatarCompanion widget
//
// Renders an animated avatar emoji circle with a connected speech bubble.
// The bubble contains the companion message and a tap-to-speak TTS button.
//
// Usage:
//   AvatarCompanion(
//     avatarEmoji: '🐰',
//     message: AvatarMessages.welcome(name, avatarId),
//   )
//
// Design notes:
//   • Avatar sits on the RIGHT, bubble extends LEFT — natural for Arabic RTL.
//   • A small triangle arrow visually connects bubble → avatar.
//   • Entrance: elastic scale from the avatar's anchor point + fade-in.
//   • TTS: tap the 🔊 button to read the message aloud (NOT autoplayed).
//   • compact: true → reduced padding/font for tight layouts (hint sheets).
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../services/audio_service.dart';
import '../../theme/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

class AvatarCompanion extends StatefulWidget {
  const AvatarCompanion({
    super.key,
    required this.avatarEmoji,
    required this.message,
    this.compact = false,
    this.audioType = 'motivation',
  });

  /// The emoji character for the avatar (e.g. "🐰"). Use AvatarConfig.resolve().emoji.
  final String avatarEmoji;

  /// The message displayed in the speech bubble.
  /// Must be non-empty. Prefer AvatarMessages.*() helpers.
  final String message;

  /// Reduces padding and font sizes for use inside bottom-sheets or overlays.
  final bool compact;

  /// Content-type hint for backend voice style: welcome | motivation | hint | general
  final String audioType;

  @override
  State<AvatarCompanion> createState() => _AvatarCompanionState();
}

class _AvatarCompanionState extends State<AvatarCompanion>
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
      duration: const Duration(milliseconds: 420),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    if (_speaking || _loading) AudioService.instance.stop();
    super.dispose();
  }

  Future<void> _toggleSpeech() async {
    if (_loading) return;
    if (_speaking) {
      await AudioService.instance.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    final avatarSize = widget.compact ? 46.0 : 58.0;
    final avatarFontSize = widget.compact ? 24.0 : 32.0;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        // Anchor the scale animation at the right side (avatar side) so
        // the bubble appears to grow outward from the avatar.
        scale: _scale,
        alignment: Alignment.centerRight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Speech bubble ────────────────────────────────────
            Expanded(
              child: _SpeechBubble(
                message: widget.message,
                compact: widget.compact,
                loading: _loading,
                speaking: _speaking,
                onSpeak: _toggleSpeech,
              ),
            ),

            // ── Arrow connecting bubble → avatar ─────────────────
            SizedBox(
              width: 11,
              height: 22,
              child: CustomPaint(painter: _ArrowPainter()),
            ),

            // ── Avatar circle ────────────────────────────────────
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
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                widget.avatarEmoji,
                style: TextStyle(fontSize: avatarFontSize),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Speech bubble container
// ─────────────────────────────────────────────────────────────────────────────

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.message,
    required this.compact,
    required this.loading,
    required this.speaking,
    required this.onSpeak,
  });

  final String message;
  final bool compact;
  final bool loading;
  final bool speaking;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        compact ? 9 : 12,
        compact ? 8 : 10,
        compact ? 9 : 12,
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
          // Message text — RTL Arabic
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),

          const SizedBox(width: 4),

          // Speaker button — loading spinner while backend generates audio,
          // stop icon while playing, volume icon when idle.
          GestureDetector(
            onTap: loading ? null : onSpeak,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 34,
              height: 34,
              child: loading
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
                        color: speaking
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        speaking
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_rounded,
                        size: 22,
                        color: speaking ? AppColors.danger : AppColors.primary,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Triangle arrow — points right, connecting the bubble to the avatar
// ─────────────────────────────────────────────────────────────────────────────

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = const Color(0xFFFFF8DC)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFFFFD580)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Triangle pointing right (toward the avatar)
    final cx = size.height / 2;
    final path = Path()
      ..moveTo(0, cx - 7)
      ..lineTo(0, cx + 7)
      ..lineTo(size.width, cx)
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_ArrowPainter _) => false;
}
