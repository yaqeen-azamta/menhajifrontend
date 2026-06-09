import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/avatar_config.dart';
import '../theme/theme.dart';

// ─────────────────────────────────────────────────────────────
// AvatarPickerWidget
//
// Reusable avatar selection grid that enforces unlock thresholds.
//
// Usage:
//   • Pass userPoints = 0 during new student registration or when
//     a parent creates a child account (child has not earned points yet).
//   • Pass the student's real totalPoints when showing the picker in
//     a settings or profile screen after the student is active.
//
// Contract:
//   • [onSelect] is called only for unlocked avatars.
//   • Tapping a locked avatar shows a SnackBar explaining the requirement.
//   • The widget is stateless — callers own the selectedId state.
//
// Scalability: new avatars are added only to AvatarConfig.all;
// this widget re-renders automatically.
// ─────────────────────────────────────────────────────────────

class AvatarPickerWidget extends StatelessWidget {
  const AvatarPickerWidget({
    super.key,
    required this.selectedId,
    required this.userPoints,
    required this.onSelect,
    this.crossAxisCount = 5,
  });

  final String selectedId;
  final int userPoints; // student's current total points
  final ValueChanged<String> onSelect;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    final avatars = AvatarConfig.all;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        // Slightly taller than square to accommodate the lock/points label.
        childAspectRatio: 0.82,
      ),
      itemCount: avatars.length,
      itemBuilder: (ctx, i) {
        final av = avatars[i];
        final unlocked = av.isUnlocked(userPoints);
        final selected = selectedId == av.id;
        return _AvatarPickerTile(
          av: av,
          unlocked: unlocked,
          selected: selected,
          onTap: () {
            if (!unlocked) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                    AppStrings.avatarUnlockRequires(av.name, av.unlockPoints),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: const Color(0xFF5C5C5C),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            } else {
              onSelect(av.id);
            }
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _AvatarPickerTile — a single cell in the picker grid
// ─────────────────────────────────────────────────────────────

class _AvatarPickerTile extends StatelessWidget {
  const _AvatarPickerTile({
    required this.av,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  final AvatarDef av;
  final bool unlocked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: !unlocked
              ? const Color(0xFFF0F0F0)
              : selected
                  ? AppColors.secondary.withValues(alpha: 0.15)
                  : const Color(0xFFF0F6FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.secondary
                : unlocked
                    ? const Color(0xFFE0D4C0)
                    : const Color(0xFFD4D4D4),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Emoji with lock/check badge ───────────────
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: unlocked ? 1.0 : 0.30,
                  child: Text(av.emoji, style: const TextStyle(fontSize: 24)),
                ),
                if (!unlocked)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: const BoxDecoration(
                        color: Color(0xFFAAAAAA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (unlocked && selected)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 4),

            // ── Status label ──────────────────────────────
            Text(
              unlocked
                  ? selected
                      ? AppStrings.avatarSelected
                      : AppStrings.avatarAvailable
                  : AppStrings.avatarRequiredPoints(av.unlockPoints),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: unlocked
                    ? selected
                        ? AppColors.secondary
                        : AppColors.primary
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
