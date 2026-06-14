import '../models/adaptive_quiz_models.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────────────────────
// AdaptiveQuizService
//
// Covers the three adaptive quiz endpoints:
//   GET  /api/quiz/adaptive/{lessonId}
//   POST /api/quiz/adaptive/{attemptId}/submit
//   GET  /api/quiz/adaptive/{attemptId}/question/{questionIndex}/hint?level=N
//
// The backend may wrap its JSON in {"data": {...}} or return the payload
// directly. Both cases are handled via _unwrap().
// ─────────────────────────────────────────────────────────────

class AdaptiveQuizService {
  AdaptiveQuizService._();

  static final instance = AdaptiveQuizService._();

  final _api = ApiClient.instance;

  // Prefer the nested "data" key if present, otherwise use the root map.
  Map<String, dynamic> _unwrap(Map<String, dynamic> res) =>
      (res['data'] as Map<String, dynamic>?) ?? res;

  // ── Generate or resume ─────────────────────────────────────
  //
  // Calling this for a lesson that already has an IN_PROGRESS attempt
  // transparently returns that attempt instead of creating a new one.
  // Pass studentId when called with a parent JWT so the backend resolves
  // the correct child instead of the parent account.
  Future<AdaptiveQuizPayload> generateOrResume(int lessonId,
      {int? studentId}) async {
    final query = studentId != null ? '?studentId=$studentId' : '';
    final res = await _api.get('/api/quiz/adaptive/$lessonId$query');
    return AdaptiveQuizPayload.fromJson(_unwrap(res));
  }

  // ── Batch submit ───────────────────────────────────────────
  //
  // [totalCount] is the number of questions in the payload so the result
  // model can derive incorrectCount without a second API call.
  // Pass studentId when called with a parent JWT.
  Future<AdaptiveQuizResult> submit(
    int attemptId,
    List<AdaptiveAnswer> answers,
    int totalCount, {
    int? studentId,
  }) async {
    final query = studentId != null ? '?studentId=$studentId' : '';
    final res = await _api.post(
      '/api/quiz/adaptive/$attemptId/submit$query',
      {'answers': answers.map((a) => a.toJson()).toList()},
    );
    return AdaptiveQuizResult.fromJson(_unwrap(res), totalCount: totalCount);
  }

  // ── Get hint ───────────────────────────────────────────────
  //
  // Returns the hint text on success.
  // Throws ApiException(429, message) when any hint limit is reached.
  Future<String> getHint(
    int attemptId,
    int questionIndex, {
    int level = 1,
  }) async {
    final res = await _api.getQuery(
      '/api/quiz/adaptive/$attemptId/question/$questionIndex/hint',
      {'level': level.toString()},
    );
    final data = _unwrap(res);
    return data['hint'] as String? ?? '';
  }
}
