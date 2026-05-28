import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Change this to your actual server address.
/// For Android emulator use http://10.0.2.2:8080
/// For iOS simulator or web use http://localhost:8080
const String kBaseUrl = 'http://10.0.2.2:8080';

// ─────────────────────────────────────────────────────────────
// Token storage helpers
// ─────────────────────────────────────────────────────────────
class TokenStore {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  static Future<void> save(String access, String refresh) async {
    final p = await SharedPreferences.getInstance();

    await p.setString(_accessKey, access);
    await p.setString(_refreshKey, refresh);
  }

  static Future<String?> getAccess() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_accessKey);
  }

  static Future<String?> getRefresh() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_refreshKey);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();

    await p.remove(_accessKey);
    await p.remove(_refreshKey);
  }
}

// ─────────────────────────────────────────────────────────────
// ApiClient — wraps every HTTP call
// ─────────────────────────────────────────────────────────────
class ApiClient {
  ApiClient._();

  static final instance = ApiClient._();

  final _client = http.Client();

  // ── low-level helpers ──────────────────────────────────────

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{'Content-Type': 'application/json'};

    if (auth) {
      final token = await TokenStore.getAccess();

      debugPrint('TOKEN = $token');

      if (token != null) {
        h['Authorization'] = 'Bearer $token';
      }
    }

    debugPrint('HEADERS = $h');

    return h;
  }

  Map<String, dynamic> _parse(http.Response res) {
    final raw = res.body.trim();

    debugPrint('========== API RESPONSE ==========');
    debugPrint('URL = ${res.request?.url}');
    debugPrint('STATUS = ${res.statusCode}');
    debugPrint('BODY = $raw');
    debugPrint('==================================');

    // Empty response — treat 401/403 as session-expired ApiException so
    // callers can catch it specifically and redirect to login.
    if (raw.isEmpty) {
      throw ApiException(
        res.statusCode,
        res.statusCode == 401 || res.statusCode == 403
            ? 'Session expired. Please log in again.'
            : 'Empty response from server',
      );
    }

    dynamic decoded;

    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      debugPrint('JSON PARSE ERROR = $e');

      throw Exception('Invalid JSON response:\n$raw');
    }

    // Success
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return {'data': decoded};
    }

    // Error response
    if (decoded is Map<String, dynamic>) {
      final msg =
          decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          'Unknown error';

      throw ApiException(res.statusCode, msg);
    }

    throw ApiException(res.statusCode, 'Server error');
  }

  // ───────────────────────────────────────────────────────────
  // Silent token refresh
  //
  // Executes [fn] with current auth headers. On 401 or 403, attempts
  // one token refresh and retries. If refresh also fails, throws
  // ApiException(401) so callers can redirect to login.
  // ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _withRefresh(
    Future<http.Response> Function(Map<String, String> headers) fn,
  ) async {
    final headers = await _headers();
    final res = await fn(headers);

    // Success or a non-auth error — handle normally.
    if (res.statusCode != 401 && res.statusCode != 403) {
      return _parse(res);
    }

    debugPrint('API: got ${res.statusCode} — attempting token refresh');

    try {
      final refresh = await TokenStore.getRefresh();
      if (refresh == null) {
        throw const ApiException(401, 'Session expired. Please log in again.');
      }

      final refreshRes = await _client.post(
        Uri.parse('$kBaseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );

      if (refreshRes.statusCode >= 200 && refreshRes.statusCode < 300) {
        final body = jsonDecode(refreshRes.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>;
        await TokenStore.save(
          data['accessToken'] as String,
          data['refreshToken'] as String,
        );
        debugPrint('API: token refreshed — retrying request');
        final freshHeaders = await _headers();
        return _parse(await fn(freshHeaders));
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      debugPrint('API: refresh attempt failed: $e');
    }

    // Refresh failed or produced a non-2xx — session is fully expired.
    throw const ApiException(401, 'Session expired. Please log in again.');
  }

  // ───────────────────────────────────────────────────────────
  // GET
  // ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> get(String path) =>
      _withRefresh((h) => _client.get(Uri.parse('$kBaseUrl$path'), headers: h));

  // ───────────────────────────────────────────────────────────
  // POST JSON
  // ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    // Unauthenticated calls (login / register) never need a refresh.
    if (!auth) {
      final res = await _client.post(
        Uri.parse('$kBaseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return _parse(res);
    }

    return _withRefresh(
      (h) => _client.post(
        Uri.parse('$kBaseUrl$path'),
        headers: h,
        body: jsonEncode(body),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // GET QUERY
  // ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getQuery(
    String path,
    Map<String, String> params,
  ) {
    final uri = Uri.parse('$kBaseUrl$path').replace(queryParameters: params);
    return _withRefresh((h) => _client.get(uri, headers: h));
  }

  // ───────────────────────────────────────────────────────────
  // POST MULTIPART
  // ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String fileField,
    required File file,
    required String filename,
    required String mimeType,
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('$kBaseUrl$path');

    final request = http.MultipartRequest('POST', uri);

    final token = await TokenStore.getAccess();

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (fields != null) {
      request.fields.addAll(fields);
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        fileField,
        file.path,
        filename: filename,
      ),
    );

    final streamed = await request.send();

    final response = await http.Response.fromStream(streamed);

    return _parse(response);
  }
}

// ─────────────────────────────────────────────────────────────
// ApiException
// ─────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() {
    return 'ApiException($statusCode): $message';
  }
}
