import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_strings.dart';
import '../models/avatar_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/theme.dart';
import '../widgets/fat_button.dart';

class StudentRegisterScreen extends StatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _schoolC = TextEditingController();

  int _gradeLevel = 1;
  String _avatarId = 'rabbit';
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _passC.dispose();
    _schoolC.dispose();
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
    if (pass.length < 6) {
      setState(() => _error = AppStrings.profilesPasswordTooShort);
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = AppStrings.profilesInvalidEmail);
      return;
    }

    setState(() => _loading = true);

    try {
      final result = await AuthService.instance.register(
        fullName: name,
        email: email,
        password: pass,
        role: 'STUDENT',
        gradeLevel: _gradeLevel,
        school: _schoolC.text.trim().isEmpty ? null : _schoolC.text.trim(),
        avatarId: _avatarId,
      );

      // register() does not activate the student session (to prevent
      // parent flows from overwriting the parent JWT). Activate explicitly here.
      await AuthService.instance.activateStudentSession(result);

      if (mounted) context.go('/home');
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
          AppStrings.studentRegTitle,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_nameC, AppStrings.studentName,
                  icon: Icons.person_outline),
              _field(_emailC, AppStrings.emailHint,
                  keyboard: TextInputType.emailAddress,
                  icon: Icons.email_outlined),
              _passwordField(),
              _field(_schoolC, AppStrings.studentSchool,
                  icon: Icons.school_outlined, required: false),

              const SizedBox(height: 4),
              _sectionLabel(AppStrings.studentGradeLevel),
              const SizedBox(height: 8),
              _gradeSelector(),

              const SizedBox(height: 20),
              _sectionLabel(AppStrings.studentChooseAvatar),
              const SizedBox(height: 12),
              _avatarGrid(),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
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

              const SizedBox(height: 24),
              FatButton(
                label: AppStrings.registerBtn,
                onPressed: _loading ? null : _submit,
                loading: _loading,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      );

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
            borderSide: const BorderSide(color: AppColors.secondary, width: 2),
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
            borderSide: const BorderSide(color: AppColors.secondary, width: 2),
          ),
          hintStyle: const TextStyle(
              color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _gradeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(6, (i) {
        final grade = i + 1;
        final selected = _gradeLevel == grade;
        return GestureDetector(
          onTap: () => setState(() => _gradeLevel = grade),
          child: Container(
            width: 56,
            height: 52,
            decoration: BoxDecoration(
              color: selected ? AppColors.secondary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.secondary : const Color(0xFFE8DCC8),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                '${AppStrings.studentGradePrefix}\n$grade',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _avatarGrid() {
    final avatars = AvatarConfig.all;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: avatars.length,
      itemBuilder: (_, i) {
        final av = avatars[i];
        final selected = _avatarId == av.id;
        return GestureDetector(
          onTap: () => setState(() => _avatarId = av.id),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.secondary.withValues(alpha: 0.15)
                  : const Color(0xFFF0F6FB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.secondary : const Color(0xFFE8DCC8),
                width: 2.5,
              ),
            ),
            child: Center(
              child: Text(
                av.emoji,
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
        );
      },
    );
  }
}

