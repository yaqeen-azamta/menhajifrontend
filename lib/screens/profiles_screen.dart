import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../models/avatar_config.dart';
import '../screens/parent_dashboard_screen.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/parent_progress_service.dart';
import '../theme/theme.dart';
import '../widgets/fat_button.dart';

class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  bool _loading = true;
  String? _error;
  ParentDashboardModel? _dashboard;
  int? _parentId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Ensure parent JWT is active when on this screen
    await AuthService.instance.switchToParent();
    _parentId = await AuthService.instance.getParentId();
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dashboard = await ParentService.instance.getDashboard();
      debugPrint('=== ParentDashboard ===');
      debugPrint(
        'parentId: ${dashboard.parentId}  children: ${dashboard.children.length}',
      );
      for (final c in dashboard.children) {
        debugPrint('  child → studentId=${c.studentId}  name=${c.fullName}');
      }
      setState(() => _dashboard = dashboard);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDashboard() {
    if (_dashboard == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentDashboardScreen(dashboard: _dashboard!),
      ),
    );
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) context.go('/login');
  }

  // ── Select child — swap JWT to child's token ───────────────
  Future<void> _selectChild(ChildSummaryModel child) async {
    debugPrint(
      'Selecting child: studentId=${child.studentId}  name=${child.fullName}',
    );

    // 1. Save child info to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_student_id', child.studentId);
    await prefs.setInt('active_grade_level', child.gradeLevel);
    await prefs.setString('active_student_name', child.fullName);
    await prefs.setString(
      'active_student_avatar',
      child.avatarId ?? 'rabbit',
    );

    debugPrint(
      'SAVED active_student_id = ${prefs.getInt('active_student_id')}',
    );
    debugPrint(
      'SAVED active_grade_level = ${prefs.getInt('active_grade_level')}',
    );
    debugPrint(
      'SAVED active_student_name = ${prefs.getString('active_student_name')}',
    );

    // 2. Swap the active JWT to the child's token
    //    → all subsequent API calls will use the student's token
    //    → backend principal = child.studentId (not parent id)
    await AuthService.instance.switchToChild(child.studentId);

    if (mounted) context.go('/home');
  }

  // ── Add kid sheet ──────────────────────────────────────────
  Future<void> _showAddSheet() async {
    if (_parentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.profilesParentNotFound),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final nameC = TextEditingController();
    final emailC = TextEditingController();
    final passC = TextEditingController();
    int gradeLevel = 1;
    String avatarId = 'fox';
    bool busy = false;
    String? err;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    AppStrings.profilesAddKidTitle,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    AppStrings.profilesAddKidSubtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                _field(nameC, AppStrings.profilesChildName),
                _field(
                  emailC,
                  AppStrings.profilesChildEmail,
                  keyboard: TextInputType.emailAddress,
                ),
                _field(passC, AppStrings.profilesChildPassword, obscure: true),

                // Grade picker
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    AppStrings.profilesGradeLevel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 6,
                    itemBuilder: (_, i) {
                      final g = i + 1;
                      final selected = gradeLevel == g;
                      return GestureDetector(
                        onTap: () => setS(() => gradeLevel = g),
                        child: Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFFFAF8EE),
                            border: selected
                                ? Border.all(
                                    color: AppColors.primaryShadow,
                                    width: 2,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$g',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  AppStrings.profilesChooseAvatar,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AvatarConfig.all.map((a) {
                    final sel = avatarId == a.id;
                    return GestureDetector(
                      onTap: () => setS(() => avatarId = a.id),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sel
                              ? const Color(0xFFFFF3E0)
                              : const Color(0xFFFAF8EE),
                          border: sel
                              ? Border.all(color: AppColors.primary, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          a.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                if (err != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      err!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                FatButton(
                  label: AppStrings.profilesCreateAccount,
                  loading: busy,
                  onPressed: busy
                      ? null
                      : () async {
                          final name = nameC.text.trim();
                          final email = emailC.text.trim();
                          final pass = passC.text;

                          if (name.isEmpty) {
                            setS(() => err = AppStrings.profilesNameRequired);
                            return;
                          }
                          if (email.isEmpty || !email.contains('@')) {
                            setS(() => err = AppStrings.profilesInvalidEmail);
                            return;
                          }
                          if (pass.length < 6) {
                            setS(
                              () =>
                                  err = AppStrings.profilesPasswordTooShort,
                            );
                            return;
                          }

                          setS(() {
                            busy = true;
                            err = null;
                          });

                          try {
                            // POST /api/auth/register  role=STUDENT
                            // Response includes child's own accessToken
                            // _persist() saves it as student_access_token_{userId}
                            final result = await AuthService.instance.register(
                              fullName: name,
                              email: email,
                              password: pass,
                              role: 'STUDENT',
                              gradeLevel: gradeLevel,
                              parentId: _parentId,
                              avatarId: avatarId,
                            );

                            debugPrint(
                              'Registered child: userId=${result.userId}  token saved',
                            );

                            if (ctx.mounted) Navigator.pop(ctx);
                            _load(); // refresh dashboard
                          } on ApiException catch (e) {
                            setS(() => err = e.message);
                          } catch (_) {
                            setS(
                              () => err = AppStrings.profilesCreateFailed,
                            );
                          } finally {
                            setS(() => busy = false);
                          }
                        },
                ),

                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      AppStrings.cancel,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FatButton(label: 'Retry', onPressed: _load),
              ],
            ),
          ),
        ),
      );
    }

    final d = _dashboard!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${AppStrings.profilesGreeting}، ${d.fullName} 👋',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          AppStrings.profilesWhoLearning,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_dashboard != null)
                    IconButton(
                      onPressed: _openDashboard,
                      tooltip: 'لوحة التقدم',
                      icon: const Icon(
                        Icons.bar_chart_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                  IconButton(
                    onPressed: _logout,
                    icon: const Icon(
                      Icons.logout,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // PROFILES GRID
            Expanded(
              child: d.children.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('👶', style: TextStyle(fontSize: 64)),
                            const SizedBox(height: 16),
                            const Text(
                              AppStrings.profilesNoKids,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FatButton(
                              label: AppStrings.profilesAddKidBtn,
                              onPressed: _showAddSheet,
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final child in d.children)
                            _ProfileCard(
                              name: child.fullName,
                              avatar: AvatarConfig.resolve(child.avatarId).emoji,
                              stars: child.totalPoints,
                              streak: child.currentStreak,
                              onTap: () => _selectChild(child),
                            ),
                          _AddCard(onTap: _showAddSheet),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────

Widget _field(
  TextEditingController c,
  String hint, {
  bool obscure = false,
  TextInputType? keyboard,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFFAF8EE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.avatar,
    required this.stars,
    required this.streak,
    required this.onTap,
  });
  final String name, avatar;
  final int stars, streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(avatar, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '⭐ $stars',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '🔥 $streak',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle, size: 56, color: AppColors.primary),
            SizedBox(height: 8),
            Text(
              AppStrings.profilesAddKid,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
