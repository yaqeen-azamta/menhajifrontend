import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../theme/theme.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  String _name = '';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final p = await SharedPreferences.getInstance();
    final name = p.getString('teacher_full_name') ?? '';
    if (mounted) setState(() => _name = name);
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          AppStrings.teacherDashTitle,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
            tooltip: AppStrings.teacherDashLogout,
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Text('📚', style: TextStyle(fontSize: 44)),
                ),
              ),
              const SizedBox(height: 16),
              if (_name.isNotEmpty)
                Text(
                  'أهلاً، $_name!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                )
              else
                const Text(
                  AppStrings.teacherDashWelcome,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              const SizedBox(height: 48),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.purple.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.construction_rounded,
                      size: 48,
                      color: AppColors.purple.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      AppStrings.teacherDashComingSoon,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
