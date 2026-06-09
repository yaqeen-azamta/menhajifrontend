import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/parent_progress_service.dart';
import '../theme/theme.dart';
import '../widgets/avatar_picker_widget.dart';

class ChangeAvatarScreen extends StatefulWidget {
  const ChangeAvatarScreen({super.key});

  @override
  State<ChangeAvatarScreen> createState() => _ChangeAvatarScreenState();
}

class _ChangeAvatarScreenState extends State<ChangeAvatarScreen> {
  String _selectedId = 'rabbit';
  int _totalPoints = 0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedId = prefs.getString('active_student_avatar') ?? 'rabbit';

    final studentId = prefs.getInt('active_student_id');
    if (studentId != null) {
      try {
        final summary = await ProgressService.instance.getSummary(studentId);
        if (mounted) setState(() => _totalPoints = summary.totalPoints);
      } catch (_) {
        // show picker with 0 points — student can still see what's locked
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AuthService.instance.updateAvatar(_selectedId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✅ تم تغيير الشخصية بنجاح',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop(true); // signal to caller that avatar changed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── top bar ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.chevron_left, size: 28),
                  ),
                  const Expanded(
                    child: Text(
                      'تغيير الشخصية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── content ───────────────────────────────────────
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Points summary chip
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFE8DCC8),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            'نقاطك الحالية: ⭐ $_totalPoints',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Avatar grid
                      AvatarPickerWidget(
                        selectedId: _selectedId,
                        userPoints: _totalPoints,
                        onSelect: (id) => setState(() => _selectedId = id),
                        crossAxisCount: 4,
                      ),

                      const SizedBox(height: 28),

                      // Save button
                      _SaveButton(saving: _saving, onPressed: _save),
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

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onPressed});
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: saving ? const Color(0xFFBDBDBD) : AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: saving
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primaryShadow.withValues(alpha: 0.5),
                    offset: const Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: saving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : const Text(
                'حفظ الشخصية',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
