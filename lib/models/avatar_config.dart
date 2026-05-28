// Centralized avatar registry.
// Store only the `id` (e.g. "fox") in the database and in SharedPreferences.
// Call AvatarConfig.resolve(id) to get the display emoji and metadata.

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
}

class AvatarConfig {
  AvatarConfig._();

  static const AvatarDef _fallback = AvatarDef(
    id: 'rabbit',
    emoji: '🐰',
    name: 'الأرنب',
    unlockPoints: 0,
  );

  static const List<AvatarDef> all = [
    AvatarDef(id: 'rabbit', emoji: '🐰', name: 'الأرنب', unlockPoints: 0),
    AvatarDef(id: 'fox', emoji: '🦊', name: 'الثعلب', unlockPoints: 0),
    AvatarDef(id: 'panda', emoji: '🐼', name: 'الباندا', unlockPoints: 200),
    AvatarDef(id: 'tiger', emoji: '🐯', name: 'النمر', unlockPoints: 400),
    AvatarDef(id: 'dog', emoji: '🐶', name: 'الكلب', unlockPoints: 600),
    AvatarDef(
      id: 'unicorn',
      emoji: '🦄',
      name: 'اليونيكورن',
      unlockPoints: 800,
    ),
    AvatarDef(id: 'frog', emoji: '🐸', name: 'الضفدع', unlockPoints: 1000),
    AvatarDef(id: 'monkey', emoji: '🐵', name: 'القرد', unlockPoints: 1200),
    AvatarDef(id: 'lion', emoji: '🦁', name: 'الأسد', unlockPoints: 1500),
    AvatarDef(id: 'koala', emoji: '🐨', name: 'الكوالا', unlockPoints: 2000),
  ];

  /// Accepts an avatarId string ("fox"), a legacy emoji ("🦊"), or null.
  /// Always returns a valid AvatarDef — never throws.
  static AvatarDef resolve(String? raw) {
    if (raw == null || raw.isEmpty) return _fallback;
    // Match by id first (new format)
    for (final a in all) {
      if (a.id == raw) return a;
    }
    // Match by emoji (legacy format where emoji was stored directly)
    for (final a in all) {
      if (a.emoji == raw) return a;
    }
    return _fallback;
  }
}
