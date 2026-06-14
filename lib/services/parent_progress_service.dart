import 'api_client.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// Parent dashboard models
// ─────────────────────────────────────────────────────────────
class ChildSummaryModel {
  final int studentId;
  final String fullName;
  final String? avatarId;
  final int gradeLevel;
  final int totalPoints;
  final int currentStreak;
  final int lessonsCompleted;
  final int totalLessons;
  final double overallMastery;

  const ChildSummaryModel({
    required this.studentId,
    required this.fullName,
    this.avatarId,
    required this.gradeLevel,
    required this.totalPoints,
    required this.currentStreak,
    required this.lessonsCompleted,
    required this.totalLessons,
    required this.overallMastery,
  });

  factory ChildSummaryModel.fromJson(Map<String, dynamic> j) =>
      ChildSummaryModel(
        studentId: j['studentId'] as int,
        fullName: j['fullName'] as String,
        avatarId: j['avatarId'] as String?,
        gradeLevel: j['gradeLevel'] as int? ?? 1,
        totalPoints: j['totalPoints'] as int? ?? 0,
        currentStreak: j['currentStreak'] as int? ?? 0,
        lessonsCompleted: j['lessonsCompleted'] as int? ?? 0,
        totalLessons: j['totalLessons'] as int? ?? 0,
        overallMastery: (j['overallMastery'] as num?)?.toDouble() ?? 0.0,
      );
}

class ParentDashboardModel {
  final int parentId;
  final String fullName;
  final List<ChildSummaryModel> children;

  const ParentDashboardModel({
    required this.parentId,
    required this.fullName,
    required this.children,
  });

  factory ParentDashboardModel.fromJson(Map<String, dynamic> j) =>
      ParentDashboardModel(
        parentId: j['parentId'] as int,
        fullName: j['fullName'] as String,
        children: (j['children'] as List<dynamic>? ?? [])
            .map((e) => ChildSummaryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ─────────────────────────────────────────────────────────────
// Child detail model  (from GET /api/parent/children/{childId})
// Maps StudentDetailResponse from the backend
// ─────────────────────────────────────────────────────────────
class SubjectMasteryModel {
  final int subjectId;
  final String subjectName;
  final int totalLessons;
  final int lessonsCompleted;
  final double averageMastery;
  final String? coverImage;

  const SubjectMasteryModel({
    required this.subjectId,
    required this.subjectName,
    required this.totalLessons,
    required this.lessonsCompleted,
    required this.averageMastery,
    this.coverImage,
  });

  factory SubjectMasteryModel.fromJson(Map<String, dynamic> j) =>
      SubjectMasteryModel(
        subjectId: j['subjectId'] as int? ?? 0,
        subjectName: j['subjectName'] as String? ?? '',
        totalLessons: j['totalLessons'] as int? ?? 0,
        lessonsCompleted: j['lessonsCompleted'] as int? ?? 0,
        averageMastery: (j['averageMastery'] as num?)?.toDouble() ?? 0.0,
        coverImage: j['coverImage'] as String?,
      );

  // Map backend subject name → local theme key
  String get key {
    final n = subjectName.toLowerCase();
    if (n.contains('math') || n.contains('رياض')) return 'math';
    if (n.contains('read') ||
        n.contains('arabic') ||
        n.contains('english') ||
        n.contains('عرب')) {
      return 'reading';
    }
    return 'science';
  }

  String get emoji {
    switch (key) {
      case 'reading':
        return '📖';
      case 'science':
        return '🔬';
      default:
        return '🔢';
    }
  }
}

class ChildDetailModel {
  final int studentId;
  final String fullName;
  final int gradeLevel;
  final int totalPoints;
  final int currentStreak;
  final int lessonsCompleted;
  final int lessonsInProgress;
  final int totalLessons;
  final double overallMastery;
  final int totalQuizzesTaken;
  final double averageQuizScore;
  final List<SubjectMasteryModel> subjectBreakdown;

  const ChildDetailModel({
    required this.studentId,
    required this.fullName,
    required this.gradeLevel,
    required this.totalPoints,
    required this.currentStreak,
    required this.lessonsCompleted,
    required this.lessonsInProgress,
    required this.totalLessons,
    required this.overallMastery,
    required this.totalQuizzesTaken,
    required this.averageQuizScore,
    required this.subjectBreakdown,
  });

  /// Total lessons: prefer the explicit field; fall back to sum of subjects.
  int get effectiveTotalLessons =>
      totalLessons > 0
          ? totalLessons
          : subjectBreakdown.fold(0, (s, e) => s + e.totalLessons);

  factory ChildDetailModel.fromJson(Map<String, dynamic> j) => ChildDetailModel(
    studentId: j['studentId'] as int? ?? 0,
    fullName: j['fullName'] as String? ?? '',
    gradeLevel: j['gradeLevel'] as int? ?? 1,
    totalPoints: j['totalPoints'] as int? ?? 0,
    currentStreak: j['currentStreak'] as int? ?? 0,
    lessonsCompleted: j['lessonsCompleted'] as int? ?? 0,
    lessonsInProgress: j['lessonsInProgress'] as int? ?? 0,
    totalLessons: j['totalLessons'] as int? ?? 0,
    overallMastery: (j['overallMastery'] as num?)?.toDouble() ?? 0.0,
    totalQuizzesTaken: j['totalQuizzesTaken'] as int? ?? 0,
    averageQuizScore: (j['averageQuizScore'] as num?)?.toDouble() ?? 0.0,
    subjectBreakdown: (j['subjectBreakdown'] as List<dynamic>? ?? [])
        .map((e) => SubjectMasteryModel.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ─────────────────────────────────────────────────────────────
// ParentService
// ─────────────────────────────────────────────────────────────
class ParentService {
  ParentService._();
  static final instance = ParentService._();

  final _api = ApiClient.instance;

  // GET /api/parent/dashboard
  // Called with the parent's JWT → returns their children list
  Future<ParentDashboardModel> getDashboard() async {
    final res = await _api.get('/api/parent/dashboard');
    return ParentDashboardModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  // GET /api/parent/children/{childId}
  // Called with the parent's JWT + the selected child's id
  // Returns full StudentDetailResponse including subjectBreakdown

  Future<ChildDetailModel> getChildDetail(int childId) async {
    final res = await _api.get('/api/parent/children/$childId');

    debugPrint('========== CHILD DETAIL API ==========');
    debugPrint(res.toString());
    debugPrint('======================================');

    final map = res;
    if (map.containsKey('data') && map['data'] != null) {
      return ChildDetailModel.fromJson(map['data'] as Map<String, dynamic>);
    }
    return ChildDetailModel.fromJson(map);
  }
}

// ─────────────────────────────────────────────────────────────
// Student dashboard models
// ─────────────────────────────────────────────────────────────
class RecommendedLesson {
  final int lessonId;
  final String title;
  final int subjectId;
  final String subjectName;
  final int orderIndex;

  const RecommendedLesson({
    required this.lessonId,
    required this.title,
    required this.subjectId,
    required this.subjectName,
    required this.orderIndex,
  });

  factory RecommendedLesson.fromJson(Map<String, dynamic> j) => RecommendedLesson(
    lessonId: j['lessonId'] as int,
    title: j['title'] as String,
    subjectId: j['subjectId'] as int,
    subjectName: j['subjectName'] as String,
    orderIndex: j['orderIndex'] as int? ?? 0,
  );
}

class StudentDashboardModel {
  final int dailyGoal;
  final int completedToday;
  final RecommendedLesson? recommendedLesson;

  const StudentDashboardModel({
    required this.dailyGoal,
    required this.completedToday,
    this.recommendedLesson,
  });

  factory StudentDashboardModel.fromJson(Map<String, dynamic> j) =>
      StudentDashboardModel(
        dailyGoal: j['dailyGoal'] as int? ?? 0,
        completedToday: j['completedToday'] as int? ?? 0,
        recommendedLesson: j['recommendedLesson'] == null
            ? null
            : RecommendedLesson.fromJson(
                j['recommendedLesson'] as Map<String, dynamic>),
      );
}

// ─────────────────────────────────────────────────────────────
// Progress models
// ─────────────────────────────────────────────────────────────
class ProgressSummaryModel {
  final int totalLessons;
  final int completedLessons;
  final int masteredLessons;
  final double overallMastery;
  final int totalPoints;
  final int currentStreak;
  final int totalQuizzesTaken;
  final double averageQuizScore;

  const ProgressSummaryModel({
    required this.totalLessons,
    required this.completedLessons,
    required this.masteredLessons,
    required this.overallMastery,
    required this.totalPoints,
    required this.currentStreak,
    required this.totalQuizzesTaken,
    required this.averageQuizScore,
  });

  factory ProgressSummaryModel.fromJson(Map<String, dynamic> j) =>
      ProgressSummaryModel(
        totalLessons: j['totalLessons'] as int? ?? 0,
        completedLessons: j['completedLessons'] as int? ?? 0,
        masteredLessons: j['masteredLessons'] as int? ?? 0,
        overallMastery: (j['overallMastery'] as num?)?.toDouble() ?? 0.0,
        totalPoints: j['totalPoints'] as int? ?? 0,
        currentStreak: j['currentStreak'] as int? ?? 0,
        totalQuizzesTaken: j['totalQuizzesTaken'] as int? ?? 0,
        averageQuizScore: (j['averageQuizScore'] as num?)?.toDouble() ?? 0.0,
      );
}

class LeaderboardEntryModel {
  final int rank;
  final int studentId;
  final String studentName;
  final String? avatarId;
  final int totalPoints;
  final int completedLessons;
  final bool isCurrentUser;

  const LeaderboardEntryModel({
    required this.rank,
    required this.studentId,
    required this.studentName,
    this.avatarId,
    required this.totalPoints,
    required this.completedLessons,
    required this.isCurrentUser,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> j) =>
      LeaderboardEntryModel(
        rank: j['rank'] as int,
        studentId: j['studentId'] as int,
        studentName: j['studentName'] as String,
        avatarId: j['avatarId'] as String?,
        totalPoints: j['totalPoints'] as int? ?? 0,
        completedLessons: j['completedLessons'] as int? ?? 0,
        isCurrentUser: j['isCurrentUser'] as bool? ?? false,
      );
}

// ─────────────────────────────────────────────────────────────
// ProgressService
// ─────────────────────────────────────────────────────────────
class ProgressService {
  ProgressService._();
  static final instance = ProgressService._();

  final _api = ApiClient.instance;

  // GET /api/progress/summary  (requires student JWT)
  Future<ProgressSummaryModel> getSummary(int studentId) async {
    final res = await _api.getQuery('/api/progress/summary', {
      'studentId': studentId.toString(),
    });

    return ProgressSummaryModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  // GET /api/student/dashboard  (requires student JWT)
  Future<StudentDashboardModel> getStudentDashboard() async {
    final res = await _api.get('/api/student/dashboard');
    final data = res['data'] as Map<String, dynamic>;
    return StudentDashboardModel.fromJson(data);
  }

  // GET /api/progress/leaderboard?gradeLevel={grade}
  Future<List<LeaderboardEntryModel>> getLeaderboard({int? gradeLevel}) async {
    final params = gradeLevel != null
        ? {'gradeLevel': gradeLevel.toString()}
        : <String, String>{};
    final res = await _api.getQuery('/api/progress/leaderboard', params);
    final list = res['data'] as List<dynamic>;
    return list
        .map((e) => LeaderboardEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
