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

  const SubjectModel({
    required this.id,
    required this.name,
    required this.gradeLevel,
    required this.totalLessons,
    required this.completedLessons,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> j) => SubjectModel(
    id: j['id'] as int,
    name: j['name'] as String,
    gradeLevel: j['gradeLevel'] as int? ?? 0,
    totalLessons: j['totalLessons'] as int? ?? 0,
    completedLessons: j['completedLessons'] as int? ?? 0,
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

  const LessonSummaryModel({
    required this.id,
    required this.title,
    required this.orderIndex,
    required this.semesterNumber,
    required this.completionStatus,
    required this.masteryLevel,
  });

  factory LessonSummaryModel.fromJson(Map<String, dynamic> j) =>
      LessonSummaryModel(
        id: j['id'] as int,
        title: j['title'] as String,
        orderIndex: j['orderIndex'] as int? ?? 0,
        semesterNumber: j['semesterNumber'] as int? ?? 1,
        completionStatus: j['completionStatus'] as String? ?? 'NOT_STARTED',
        masteryLevel: (j['masteryLevel'] as num?)?.toDouble() ?? 0.0,
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
      );
}

// ─────────────────────────────────────────────────────────────
// LessonService
// ─────────────────────────────────────────────────────────────
class LessonService {
  LessonService._();
  static final instance = LessonService._();

  final _api = ApiClient.instance;

  // GET /api/lessons/subjects?gradeLevel={grade}
  Future<List<SubjectModel>> getSubjects(int gradeLevel) async {
    final res = await _api.getQuery('/api/lessons/subjects', {
      'gradeLevel': gradeLevel.toString(),
    });
    final list = res['data'] as List<dynamic>;
    return list
        .map((e) => SubjectModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // GET /api/lessons/subject/{subjectId}
  Future<List<LessonSummaryModel>> getLessonsBySubject(int subjectId) async {
    final res = await _api.get('/api/lessons/subject/$subjectId');
    final list = res['data'] as List<dynamic>;
    return list
        .map((e) => LessonSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // GET /api/lessons/{lessonId}
  Future<LessonDetailModel> getLessonDetail(int lessonId) async {
    final res = await _api.get('/api/lessons/$lessonId');
    return LessonDetailModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  // POST /api/audio/lesson/{lessonId}/narrate
  // Returns { audioUrl: "..." } or { message: "unavailable" }
  Future<String?> narrateLesson(int lessonId) async {
    final res = await _api.post('/api/audio/lesson/$lessonId/narrate', {});
    final data = res['data'] as Map<String, dynamic>;
    return data['audioUrl'] as String?;
  }

  // POST /api/audio/question/{questionId}/read
  Future<String?> narrateQuestion(int questionId) async {
    final res = await _api.post('/api/audio/question/$questionId/read', {});
    final data = res['data'] as Map<String, dynamic>;
    return data['audioUrl'] as String?;
  }

  // POST /api/progress/lesson/{lessonId}/complete
  Future<void> completeLesson(int lessonId) async {
    await _api.post('/api/progress/lesson/$lessonId/complete', {});
  }
}
