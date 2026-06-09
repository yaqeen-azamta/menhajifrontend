// Centralized avatar registry.
// Store only the `id` (e.g. "fox") in the database and in SharedPreferences.
// Call AvatarConfig.resolve(id) to get the display emoji and metadata.
//
// Unlock logic is computed entirely client-side from the user's totalPoints:
//   isUnlocked = userPoints >= avatar.unlockPoints
// No separate "unlocked" flag is stored in the database.
//
// To add new avatars: append to AvatarConfig.all keeping ascending
// unlockPoints order so that the grid always renders progressively.

class AvatarDef {
  final String id;
  final String emoji;
  final String name; // Arabic display name
  final int unlockPoints;

  const AvatarDef({
    required this.id,
    required this.emoji,
    required this.name,
    required this.unlockPoints,
  });

  /// True when the student has accumulated enough points to use this avatar.
  bool isUnlocked(int userPoints) => userPoints >= unlockPoints;
}

class AvatarConfig {
  AvatarConfig._();

  static const AvatarDef _fallback = AvatarDef(
    id: 'rabbit',
    emoji: '🐰',
    name: 'الأرنب',
    unlockPoints: 0,
  );

  /// All avatars sorted ascending by unlock threshold.
  /// Append new entries here — UI adapts automatically.
  static const List<AvatarDef> all = [
    // مفتوحة للجميع
    AvatarDef(id: 'rabbit', emoji: '🐰', name: 'الأرنب', unlockPoints: 0),
    AvatarDef(id: 'unicorn', emoji: '🦄', name: 'اليونيكورن', unlockPoints: 0),
    AvatarDef(id: 'butterfly', emoji: '🦋', name: 'الفراشة', unlockPoints: 0),
    AvatarDef(id: 'panda', emoji: '🐼', name: 'الباندا', unlockPoints: 0),
    AvatarDef(id: 'hamster', emoji: '🐹', name: 'الهامستر', unlockPoints: 0),
    AvatarDef(id: 'koala', emoji: '🐨', name: 'الكوالا', unlockPoints: 0),
    AvatarDef(id: 'penguin', emoji: '🐧', name: 'البطريق', unlockPoints: 0),

    AvatarDef(id: 'fox', emoji: '🦊', name: 'الثعلب', unlockPoints: 500),
    AvatarDef(id: 'owl', emoji: '🦉', name: 'البومة', unlockPoints: 1000),
    AvatarDef(id: 'turtle', emoji: '🐢', name: 'السلحفاة', unlockPoints: 1500),
    AvatarDef(id: 'bee', emoji: '🐝', name: 'النحلة', unlockPoints: 2000),
    AvatarDef(id: 'dolphin', emoji: '🐬', name: 'الدلفين', unlockPoints: 2500),
    AvatarDef(id: 'otter', emoji: '🦦', name: 'القضاعة', unlockPoints: 3000),
    AvatarDef(id: 'sloth', emoji: '🦥', name: 'الكسلان', unlockPoints: 3500),
    AvatarDef(id: 'bear', emoji: '🐻', name: 'الدب', unlockPoints: 4000),
    AvatarDef(id: 'lion', emoji: '🦁', name: 'الأسد', unlockPoints: 5000),
    AvatarDef(id: 'robot', emoji: '🤖', name: 'الروبوت', unlockPoints: 6500),
    AvatarDef(id: 'dragon', emoji: '🐲', name: 'التنين', unlockPoints: 8000),
    AvatarDef(id: 'queen', emoji: '👸', name: 'الملكة', unlockPoints: 10000),
    AvatarDef(id: 'king', emoji: '👑', name: 'الملك', unlockPoints: 12000),
  ];

  /// Returns avatars that crossed their unlock threshold between [oldPoints]
  /// and [newPoints].  Used to detect "new unlocks" after a quiz or lesson
  /// so the UI can celebrate.  The rabbit (0 pts) is excluded — it is always
  /// free and never treated as a "new" unlock.
  static List<AvatarDef> newlyUnlocked(int oldPoints, int newPoints) => all
      .where(
        (av) =>
            av.unlockPoints > 0 &&
            oldPoints < av.unlockPoints &&
            newPoints >= av.unlockPoints,
      )
      .toList();

  /// Accepts an avatarId string ("fox"), a legacy emoji ("🦊"), or null.
  /// Always returns a valid AvatarDef — never throws.
  static AvatarDef resolve(String? raw) {
    if (raw == null || raw.isEmpty) return _fallback;
    // Match by id first (canonical format)
    for (final a in all) {
      if (a.id == raw) return a;
    }
    // Match by emoji (legacy format where the emoji was stored directly)
    for (final a in all) {
      if (a.emoji == raw) return a;
    }
    return _fallback;
  }
}
