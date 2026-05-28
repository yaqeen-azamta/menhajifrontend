class User {
  final String id;
  final String email;
  final String name;

  const User({required this.id, required this.email, required this.name});
}

class ChildProfile {
  final String id;
  final String name;
  final String avatar;
  final int age;
  final int xp;
  final int stars;
  final int streak;

  // HomeScreen still uses these:
  final int dailyGoal;
  final int dailyProgress;

  final List<String> completedLessons;
  final List<String> badges;

  const ChildProfile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.age,
    required this.xp,
    required this.stars,
    required this.streak,
    required this.dailyGoal,
    required this.dailyProgress,
    required this.completedLessons,
    required this.badges,
  });

  // For easy frontend-only updates (copyWith)
  ChildProfile copyWith({
    String? id,
    String? name,
    String? avatar,
    int? age,
    int? xp,
    int? stars,
    int? streak,
    int? dailyGoal,
    int? dailyProgress,
    List<String>? completedLessons,
    List<String>? badges,
  }) {
    return ChildProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      age: age ?? this.age,
      xp: xp ?? this.xp,
      stars: stars ?? this.stars,
      streak: streak ?? this.streak,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      dailyProgress: dailyProgress ?? this.dailyProgress,
      completedLessons: completedLessons ?? this.completedLessons,
      badges: badges ?? this.badges,
    );
  }
}

class Lesson {
  final String id;
  final String subject;
  final String title;
  final String emoji;
  final String color;
  final String intro;
  final String concept;

  const Lesson({
    required this.id,
    required this.subject,
    required this.title,
    required this.emoji,
    required this.color,
    required this.intro,
    required this.concept,
  });
}

class QuizQuestion {
  final String q;
  final List<String> options;
  final int answerIndex;
  final String? hint;

  const QuizQuestion({
    required this.q,
    required this.options,
    required this.answerIndex,
    this.hint,
  });
}

class Badge {
  final String id;
  final String name;
  final String emoji;

  const Badge({required this.id, required this.name, required this.emoji});
}

class Profile {
  final String id;
  final String name;
  final String avatar;
  final int age;
  final int xp;
  final int stars;
  final int streak;
  final int dailyGoal;
  final int dailyProgress;
  final List<String> completedLessons;
  final List<String> badges;

  const Profile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.age,
    required this.xp,
    required this.stars,
    required this.streak,
    required this.dailyGoal,
    required this.dailyProgress,
    required this.completedLessons,
    required this.badges,
  });

  Profile copyWith({
    String? id,
    String? name,
    String? avatar,
    int? age,
    int? xp,
    int? stars,
    int? streak,
    int? dailyGoal,
    int? dailyProgress,
    List<String>? completedLessons,
    List<String>? badges,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      age: age ?? this.age,
      xp: xp ?? this.xp,
      stars: stars ?? this.stars,
      streak: streak ?? this.streak,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      dailyProgress: dailyProgress ?? this.dailyProgress,
      completedLessons: completedLessons ?? this.completedLessons,
      badges: badges ?? this.badges,
    );
  }
}

class RewardsScreenData {
  final int stars;
  final int xp;
  final int correct;
  final int total;
  final int streak;
  final String? newBadgesJson;
  final String? lessonId;

  const RewardsScreenData({
    this.stars = 0,
    this.xp = 0,
    this.correct = 0,
    this.total = 0,
    this.streak = 0,
    this.newBadgesJson,
    this.lessonId,
  });
}
