import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_strings.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/theme.dart';
import '../widgets/fat_button.dart';

class TeacherRegisterScreen extends StatefulWidget {
  const TeacherRegisterScreen({super.key});

  @override
  State<TeacherRegisterScreen> createState() => _TeacherRegisterScreenState();
}

class _TeacherRegisterScreenState extends State<TeacherRegisterScreen> {
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _schoolC = TextEditingController();
  final _subjectC = TextEditingController();
  final _specC = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _passC.dispose();
    _schoolC.dispose();
    _subjectC.dispose();
    _specC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    final name = _nameC.text.trim();
    final email = _emailC.text.trim();
    final pass = _passC.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = AppStrings.registerFillFields);
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = AppStrings.profilesInvalidEmail);
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = AppStrings.profilesPasswordTooShort);
      return;
    }

    setState(() => _loading = true);

    try {
      await AuthService.instance.register(
        fullName: name,
        email: email,
        password: pass,
        role: 'TEACHER',
        school: _schoolC.text.trim().isEmpty ? null : _schoolC.text.trim(),
        subject: _subjectC.text.trim().isEmpty ? null : _subjectC.text.trim(),
        specialization: _specC.text.trim().isEmpty ? null : _specC.text.trim(),
      );

      if (mounted) context.go('/teacher');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = AppStrings.registerFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          AppStrings.teacherRegTitle,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _RoleHeader(
                emoji: '📚',
                color: AppColors.purple,
                subtitle: 'أنشئ وأدِر المحتوى التعليمي',
              ),
              const SizedBox(height: 28),

              _field(_nameC, AppStrings.teacherName,
                  icon: Icons.person_outline),
              _field(_emailC, AppStrings.emailHint,
                  keyboard: TextInputType.emailAddress,
                  icon: Icons.email_outlined),
              _passwordField(),
              _field(_schoolC, AppStrings.teacherSchool,
                  icon: Icons.school_outlined, required: false),
              _field(_subjectC, AppStrings.teacherSubject,
                  icon: Icons.menu_book_outlined, required: false),
              _field(_specC, AppStrings.teacherSpecialization,
                  icon: Icons.workspace_premium_outlined, required: false),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),

              const SizedBox(height: 8),
              FatButton(
                label: AppStrings.registerBtn,
                onPressed: _loading ? null : _submit,
                loading: _loading,
                color: FatColor.purple,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    IconData? icon,
    TextInputType? keyboard,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          hintText: required ? hint : '$hint (اختياري)',
          prefixIcon: icon != null
              ? Icon(icon, color: AppColors.textSecondary, size: 20)
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE8DCC8), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.purple, width: 2),
          ),
          hintStyle: const TextStyle(
              color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: _passC,
        obscureText: _obscure,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          hintText: AppStrings.passwordHint,
          prefixIcon: const Icon(Icons.lock_outlined,
              color: AppColors.textSecondary, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE8DCC8), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.purple, width: 2),
          ),
          hintStyle: const TextStyle(
              color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RoleHeader extends StatelessWidget {
  final String emoji;
  final Color color;
  final String subtitle;

  const _RoleHeader({
    required this.emoji,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 36)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
