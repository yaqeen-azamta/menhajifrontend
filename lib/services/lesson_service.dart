import 'package:flutter/foundation.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────
class SubjectModel {
  final int id;
  final String name;
  final int gradeLevel;
  final int totalLessons;
  final int completedLessons;
  final String? coverImage;

  const SubjectModel({
    required this.id,
    required this.name,
    required this.gradeLevel,
    required this.totalLessons,
    required this.completedLessons,
    this.coverImage,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> j) => SubjectModel(
    id: j['id'] as int,
    name: j['name'] as String,
    gradeLevel: j['gradeLevel'] as int? ?? 0,
    totalLessons: j['totalLessons'] as int? ?? 0,
    completedLessons: j['completedLessons'] as int? ?? 0,
    coverImage: j['coverImage'] as String?,
  );
}

class LessonSummaryModel {
  final int id;
  final String title;
  final int orderIndex;
  final int semesterNumber;
  final String
  completionStatus; // "NOT_STARTED" | "IN_PROGRESS" | "COMPLETED" | "MASTERED"
  final double masteryLevel;
  final String? coverImage;

  const LessonSummaryModel({
    required this.id,
    required this.title,
    required this.orderIndex,
    required this.semesterNumber,
    required this.completionStatus,
    required this.masteryLevel,
    this.coverImage,
  });

  factory LessonSummaryModel.fromJson(Map<String, dynamic> j) =>
      LessonSummaryModel(
        id: j['id'] as int,
        title: j['title'] as String,
        orderIndex: j['orderIndex'] as int? ?? 0,
        semesterNumber: j['semesterNumber'] as int? ?? 1,
        completionStatus: j['completionStatus'] as String? ?? 'NOT_STARTED',
        masteryLevel: (j['masteryLevel'] as num?)?.toDouble() ?? 0.0,
        coverImage: j['coverImage'] as String?,
      );

  bool get isCompleted =>
      completionStatus == 'COMPLETED' || completionStatus == 'MASTERED';
}

class LessonDetailModel {
  final int id;
  final String title;
  final String content;
  final String? audioUrl;
  final List<String> imageUrls;
  final String? objectives;
  final int orderIndex;
  final int semesterNumber;
  final int subjectId;
  final String subjectName;
  final int gradeLevel;
  final int totalQuestions;
  final String? coverImage;

  const LessonDetailModel({
    required this.id,
    required this.title,
    required this.content,
    this.audioUrl,
    required this.imageUrls,
    this.objectives,
    required this.orderIndex,
    required this.semesterNumber,
    required this.subjectId,
    required this.subjectName,
    required this.gradeLevel,
    required this.totalQuestions,
    this.coverImage,
  });

  factory LessonDetailModel.fromJson(Map<String, dynamic> j) =>
      LessonDetailModel(
        id: j['id'] as int,
        title: j['title'] as String,
        content: j['content'] as String? ?? '',
        audioUrl: j['audioUrl'] as String?,
        imageUrls:
            (j['imageUrls'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        objectives: j['objectives'] as String?,
        orderIndex: j['orderIndex'] as int? ?? 0,
        semesterNumber: j['semesterNumber'] as int? ?? 1,
        subjectId: j['subjectId'] as int,
        subjectName: j['subjectName'] as String,
        gradeLevel: j['gradeLevel'] as int? ?? 0,
        totalQuestions: j['totalQuestions'] as int? ?? 0,
        coverImage: j['coverImage'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────
// LessonService
// ─────────────────────────────────────────────────────────────
class LessonService {
  LessonService._();
  static final instance = LessonService._();

  final _api = ApiClient.instance;

  // GET /api/lessons/subjects?gradeLevel={grade}[&studentId={id}]
  Future<List<SubjectModel>> getSubjects(int gradeLevel, {int? studentId}) async {
    final params = <String, String>{'gradeLevel': gradeLevel.toString()};
    if (studentId != null) params['studentId'] = studentId.toString();
    debugPrint('LessonService.getSubjects gradeLevel=$gradeLevel studentId=$studentId');
    final res = await _api.getQuery('/api/lessons/subjects', params);
    final list = res['data'] as List<dynamic>;
    return list
        .map((e) => SubjectModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // GET /api/lessons/subject/{subjectId}[?studentId={id}]
  Future<List<LessonSummaryModel>> getLessonsBySubject(int subjectId, {int? studentId}) async {
    final params = <String, String>{};
    if (studentId != null) params['studentId'] = studentId.toString();
    debugPrint('LessonService.getLessonsBySubject subjectId=$subjectId studentId=$studentId');
    final res = await _api.getQuery('/api/lessons/subject/$subjectId', params);
    final list = res['data'] as List<dynamic>;
    return list
        .map((e) => LessonSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // GET /api/lessons/{lessonId}[?studentId={id}]
  Future<LessonDetailModel> getLessonDetail(int lessonId, {int? studentId}) async {
    final params = <String, String>{};
    if (studentId != null) params['studentId'] = studentId.toString();
    debugPrint('LessonService.getLessonDetail lessonId=$lessonId studentId=$studentId');
    final res = await _api.getQuery('/api/lessons/$lessonId', params);
    return LessonDetailModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  // POST /api/audio/lesson/{lessonId}/narrate
  // Backend returns { audioUrl: "..." } at the top level (not wrapped in data).
  Future<String?> narrateLesson(int lessonId) async {
    final res = await _api.post('/api/audio/lesson/$lessonId/narrate', {});
    // Try top-level key first; fall back to nested data map if the backend ever
    // wraps the response.
    if (res['audioUrl'] is String) return res['audioUrl'] as String;
    final nested = res['data'];
    if (nested is Map<String, dynamic>) return nested['audioUrl'] as String?;
    return null;
  }

  // POST /api/audio/question/{questionId}/read
  Future<String?> narrateQuestion(int questionId) async {
    final res = await _api.post('/api/audio/question/$questionId/read', {});
    if (res['audioUrl'] is String) return res['audioUrl'] as String;
    final nested = res['data'];
    if (nested is Map<String, dynamic>) return nested['audioUrl'] as String?;
    return null;
  }

  // POST /api/progress/lesson/{lessonId}/complete[?studentId={id}]
  Future<void> completeLesson(int lessonId, {int? studentId}) async {
    final query = studentId != null ? '?studentId=$studentId' : '';
    debugPrint('LessonService.completeLesson lessonId=$lessonId studentId=$studentId');
    await _api.post('/api/progress/lesson/$lessonId/complete$query', {});
  }
}
