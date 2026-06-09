import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/avatar_config.dart';
import '../services/auth_service.dart';
import '../theme/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _name = '';
  String? _avatarId;
  int _gradeLevel = 1;
  bool _isDirectStudent = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final role = await AuthService.instance.getCurrentRole();
    if (!mounted) return;
    setState(() {
      _name = prefs.getString('active_student_name') ?? 'طالب';
      _avatarId = prefs.getString('active_student_avatar');
      _gradeLevel = prefs.getInt('active_grade_level') ?? 1;
      _isDirectStudent = role == 'STUDENT';
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final router = GoRouter.of(context);
    if (_isDirectStudent) {
      await AuthService.instance.logout();
      if (mounted) router.go('/login');
    } else {
      await AuthService.instance.switchToParent();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_student_id');
      if (mounted) router.go('/profiles');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final av = AvatarConfig.resolve(_avatarId);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'الإعدادات',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),

              // ── Profile card ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF73A5CA), Color(0xFF4A7FA8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3373A5CA),
                      offset: Offset(0, 8),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        av.emoji,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الصف $_gradeLevel',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isDirectStudent
                                ? 'حساب طالب'
                                : 'حساب مرتبط بولي الأمر',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'الحساب',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),

              // ── Change avatar ─────────────────────────────────
              _SettingsTile(
                icon: Icons.face_rounded,
                label: 'تغيير الشخصية',
                onTap: () async {
                  await context.push('/change-avatar');
                  if (mounted) _load();
                },
              ),
              const SizedBox(height: 10),

              // ── Change grade ──────────────────────────────────
              _SettingsTile(
                icon: Icons.school_rounded,
                label: 'تغيير الصف',
                onTap: () async {
                  await context.push('/change-grade');
                  if (mounted) _load();
                },
              ),
              const SizedBox(height: 10),

              // ── Change password ───────────────────────────────
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                label: 'تغيير كلمة المرور',
                onTap: () => context.push('/change-password'),
              ),
              const SizedBox(height: 10),

              // ── Logout tile ───────────────────────────────────
              _SettingsTile(
                icon: Icons.logout_rounded,
                label: _isDirectStudent
                    ? 'تسجيل الخروج'
                    : 'العودة لاختيار الطفل',
                color: AppColors.danger,
                onTap: _logout,
              ),

              const SizedBox(height: 32),

              // ── App version ───────────────────────────────────
              const Center(
                child: Text(
                  'منهاجي • الإصدار 1.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: c,
                ),
              ),
            ),
            Icon(
              Icons.chevron_left,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
