import '../../services/api_client.dart';
import '../models/tracing_submission.dart';

class TracingApiService {
  TracingApiService._();
  static final instance = TracingApiService._();

  /// POST /api/tracing/submit — sends the full tracing result to the backend.
  Future<Map<String, dynamic>> submitTracing(TracingSubmission submission) {
    return ApiClient.instance.post(
      '/api/tracing/submit',
      submission.toJson(),
    );
  }
}