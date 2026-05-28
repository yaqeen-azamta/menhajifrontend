import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

// ─────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────
class AuthResult {
  final String accessToken;
  final String refreshToken;
  final int userId;
  final int? studentId; // ✅ FIX
  final String fullName;
  final String? email;
  final String? phone;
  final String role; // "PARENT" | "STUDENT" | "TEACHER" | "ADMIN"
  final int? gradeLevel;
  final String? avatarId;

  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    this.studentId,
    required this.fullName,
    this.email,
    this.phone,
    required this.role,
    this.gradeLevel,
    this.avatarId,
  });

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
    accessToken: j['accessToken'] as String,
    refreshToken: j['refreshToken'] as String,
    userId: j['userId'] as int,
    studentId: j['studentId'] as int?,
    fullName: j['fullName'] as String,
    email: j['email'] as String?,
    phone: j['phone'] as String?,
    role: (j['role'] as String?) ?? 'PARENT',
    gradeLevel: j['gradeLevel'] as int?,
    avatarId: j['avatarId'] as String?,
  );
}

// ─────────────────────────────────────────────────────────────
// AuthService
// ─────────────────────────────────────────────────────────────
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _api = ApiClient.instance;

  // ── Store credentials after any auth operation ─────────────
  // Does NOT activate the JWT for STUDENT — call activateStudentSession()
  // explicitly for direct student login / self-registration. This prevents
  // parent-adds-child flows from overwriting the parent's active JWT.
  Future<AuthResult> _persist(Map<String, dynamic> res) async {
    final result = AuthResult.fromJson(res['data'] as Map<String, dynamic>);
    final p = await SharedPreferences.getInstance();

    if (result.role == 'PARENT') {
      await TokenStore.save(result.accessToken, result.refreshToken);
      await p.setString('current_role', 'PARENT');
      await p.setInt('parent_user_id', result.userId);
      await p.setString('parent_full_name', result.fullName);
      await p.setString('parent_access_token', result.accessToken);
      await p.setString('parent_refresh_token', result.refreshToken);
      debugPrint('Saved PARENT token');
    } else if (result.role == 'STUDENT') {
      final sid = result.studentId ?? result.userId;
      await p.setString('student_access_token_$sid', result.accessToken);
      await p.setString('student_refresh_token_$sid', result.refreshToken);
      // JWT activation intentionally omitted — call activateStudentSession().
      debugPrint('Saved STUDENT token (not yet activated) for sid=$sid');
    } else if (result.role == 'TEACHER') {
      await TokenStore.save(result.accessToken, result.refreshToken);
      await p.setString('current_role', 'TEACHER');
      await p.setInt('teacher_user_id', result.userId);
      await p.setString('teacher_full_name', result.fullName);
      await p.setString('teacher_access_token', result.accessToken);
      await p.setString('teacher_refresh_token', result.refreshToken);
      debugPrint('Saved TEACHER token');
    }

    return result;
  }

  // ── Activate a student's own session ──────────────────────
  // Call after direct student login or student self-registration.
  // Do NOT call when a parent registers a child — that must not
  // overwrite the parent's active JWT.
  Future<void> activateStudentSession(AuthResult result) async {
    final p = await SharedPreferences.getInstance();
    final sid = result.studentId ?? result.userId;

    final access = p.getString('student_access_token_$sid');
    final refresh = p.getString('student_refresh_token_$sid');
    if (access == null || refresh == null) return;

    await TokenStore.save(access, refresh);
    await p.setString('current_role', 'STUDENT');
    await p.setInt('active_student_id', sid);
    if (result.gradeLevel != null) {
      await p.setInt('active_grade_level', result.gradeLevel!);
    }
    await p.setString('active_student_name', result.fullName);
    if (result.avatarId != null) {
      await p.setString('active_student_avatar', result.avatarId!);
    }
    debugPrint('Activated STUDENT session for sid=$sid');
  }

  // ── Swap active JWT to child's token ──────────────────────
  Future<void> switchToChild(int studentId) async {
    final p = await SharedPreferences.getInstance();

    debugPrint('Switching to child token: studentId=$studentId');

    final access = p.getString('student_access_token_$studentId');

    final refresh = p.getString('student_refresh_token_$studentId');

    debugPrint('ACCESS FOUND = ${access != null}');
    debugPrint('REFRESH FOUND = ${refresh != null}');

    if (access != null && refresh != null) {
      await TokenStore.save(access, refresh);

      debugPrint('Child token activated successfully');
    } else {
      debugPrint('ERROR: Child token NOT found. Parent token still active.');
    }
  }

  // ── Restore parent JWT when going back to profile screen ──
  Future<void> switchToParent() async {
    final p = await SharedPreferences.getInstance();

    final access = p.getString('parent_access_token');
    final refresh = p.getString('parent_refresh_token');

    if (access != null && refresh != null) {
      await TokenStore.save(access, refresh);
    }
  }

  // ── POST /api/auth/register ────────────────────────────────
  // Single endpoint for all roles. Pass `role` as STUDENT | PARENT | TEACHER.
  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
    String role = 'PARENT',
    String? phone,
    int? gradeLevel,
    int? parentId,
    String? avatarId,
    String? school,
    String? subject,
    String? specialization,
  }) async {
    final body = <String, dynamic>{
      'fullName': fullName,
      'email': email,
      'password': password,
      'role': role,
      // ignore: use_null_aware_elements
      if (phone != null) 'phone': phone,
      // ignore: use_null_aware_elements
      if (gradeLevel != null) 'gradeLevel': gradeLevel,
      // ignore: use_null_aware_elements
      if (parentId != null) 'parentId': parentId,
      // ignore: use_null_aware_elements
      if (avatarId != null) 'avatarId': avatarId,
      // ignore: use_null_aware_elements
      if (school != null) 'school': school,
      // ignore: use_null_aware_elements
      if (subject != null) 'subject': subject,
      // ignore: use_null_aware_elements
      if (specialization != null) 'specialization': specialization,
    };

    final res = await _api.post('/api/auth/register', body, auth: false);

    return _persist(res);
  }

  // ── POST /api/auth/login ───────────────────────────────────
  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _api.post('/api/auth/login', {
      'email': email,
      'password': password,
    }, auth: false);

    final result = await _persist(res);

    // Student login must activate the session explicitly — _persist() skips
    // this for STUDENT to avoid corrupting parent sessions during child registration.
    if (result.role == 'STUDENT') {
      await activateStudentSession(result);
    }

    return result;
  }

  // ── POST /api/auth/login/phone ─────────────────────────────
  Future<AuthResult> loginWithPhone({
    required String phone,
    required String password,
  }) async {
    final res = await _api.post('/api/auth/login/phone', {
      'phone': phone,
      'password': password,
    }, auth: false);

    return _persist(res);
  }

  // ── POST /api/auth/refresh ─────────────────────────────────
  Future<AuthResult> refreshToken() async {
    final refresh = await TokenStore.getRefresh();

    if (refresh == null) {
      throw const ApiException(401, 'No refresh token');
    }

    final res = await _api.post('/api/auth/refresh', {
      'refreshToken': refresh,
    }, auth: false);

    return _persist(res);
  }

  // ── GET /api/auth/me ───────────────────────────────────────
  Future<AuthResult> getMe() async {
    final res = await _api.get('/api/auth/me');

    return AuthResult.fromJson(res['data'] as Map<String, dynamic>);
  }

  // ── Helpers ────────────────────────────────────────────────

  Future<String?> getCurrentRole() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('current_role');
  }

  Future<int?> getParentId() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('parent_user_id');
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();

    final keys = p
        .getKeys()
        .where(
          (k) =>
              k.startsWith('student_access_token_') ||
              k.startsWith('student_refresh_token_') ||
              k == 'current_role' ||
              k == 'parent_access_token' ||
              k == 'parent_refresh_token' ||
              k == 'parent_user_id' ||
              k == 'parent_full_name' ||
              k == 'teacher_access_token' ||
              k == 'teacher_refresh_token' ||
              k == 'teacher_user_id' ||
              k == 'teacher_full_name' ||
              k == 'active_student_id' ||
              k == 'active_grade_level' ||
              k == 'active_student_name' ||
              k == 'active_student_avatar',
        )
        .toList();

    for (final k in keys) {
      await p.remove(k);
    }

    await TokenStore.clear();
  }

  Future<bool> isLoggedIn() async {
    final token = await TokenStore.getAccess();

    return token != null;
  }
}
