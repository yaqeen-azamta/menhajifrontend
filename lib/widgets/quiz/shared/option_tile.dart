// ════════════════════════════════════════════════════════════════════════════
// option_tile.dart
// ════════════════════════════════════════════════════════════════════════════
// Big rounded tappable button used for MCQ, true/false, listen_and_choose, etc.
// Has 4 visual states: idle, selected, correct, wrong.
// Animates scale on tap for a satisfying feel.
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../../../theme/theme.dart';

enum OptionState { idle, selected, correct, wrong }

class OptionTile extends StatefulWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.locked = false,
    this.icon,
  });

  final String label;
  final OptionState state;
  final VoidCallback onTap;
  final bool locked;
  final IconData? icon;

  @override
  State<OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<OptionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.96,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _ctrl.reverse();
  void _onTapUp(_) => _ctrl.forward();
  void _onTapCancel() => _ctrl.forward();

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForState(widget.state);

    return GestureDetector(
      onTapDown: widget.locked ? null : _onTapDown,
      onTapUp: widget.locked ? null : _onTapUp,
      onTapCancel: widget.locked ? null : _onTapCancel,
      onTap: widget.locked ? null : widget.onTap,
      child: ScaleTransition(
        scale: _ctrl,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: colors.border,
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: colors.text, size: 22),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.text,
                  ),
                ),
              ),
              if (widget.state == OptionState.correct)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 24,
                ),
              if (widget.state == OptionState.wrong)
                const Icon(Icons.cancel, color: AppColors.danger, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  _TileColors _colorsForState(OptionState s) {
    switch (s) {
      case OptionState.correct:
        return _TileColors(
          background: const Color(0xFFE3F8DD),
          border: AppColors.primary,
          text: AppColors.primary,
        );
      case OptionState.wrong:
        return _TileColors(
          background: const Color(0xFFFFE8E8),
          border: AppColors.danger,
          text: AppColors.danger,
        );
      case OptionState.selected:
        return _TileColors(
          background: const Color(0xFFE6F6FE),
          border: AppColors.secondary,
          text: AppColors.secondary,
        );
      case OptionState.idle:
        return _TileColors(
          background: Colors.white,
          border: const Color(0xFFE5E5E5),
          text: AppColors.textPrimary,
        );
    }
  }
}

class _TileColors {
  final Color background;
  final Color border;
  final Color text;
  const _TileColors({
    required this.background,
    required this.border,
    required this.text,
  });
}
