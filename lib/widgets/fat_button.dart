import 'package:flutter/material.dart';
import '../theme/theme.dart';

enum FatColor { primary, secondary, gold, danger, purple }

class FatButton extends StatefulWidget {
  const FatButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = FatColor.primary,
    this.loading = false,
    this.disabled = false,
    this.small = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final FatColor color;
  final bool loading;
  final bool disabled;
  final bool small;

  @override
  State<FatButton> createState() => _FatButtonState();
}

class _FatButtonState extends State<FatButton> {
  bool _pressed = false;

  (Color, Color) _colors() {
    switch (widget.color) {
      case FatColor.primary:
        return (AppColors.primary, AppColors.primaryShadow);
      case FatColor.secondary:
        return (AppColors.secondary, AppColors.secondaryShadow);
      case FatColor.gold:
        return (AppColors.gold, AppColors.goldShadow);
      case FatColor.danger:
        return (AppColors.danger, AppColors.dangerShadow);
      case FatColor.purple:
        return (AppColors.purple, AppColors.purpleShadow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, sh) = _colors();
    final disabled =
        widget.disabled || widget.loading || widget.onPressed == null;
    final actualBg = disabled ? const Color(0xFFBDBDBD) : bg;
    final actualSh = disabled ? const Color(0xFF9E9E9E) : sh;
    final paddingV = widget.small ? 12.0 : 16.0;
    final minH = widget.small ? 48.0 : 56.0;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTap: disabled ? null : widget.onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: actualSh,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.only(bottom: _pressed ? 0 : 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          constraints: BoxConstraints(minHeight: minH),
          padding: EdgeInsets.symmetric(vertical: paddingV, horizontal: 24),
          decoration: BoxDecoration(
            color: actualBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    widget.label.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
