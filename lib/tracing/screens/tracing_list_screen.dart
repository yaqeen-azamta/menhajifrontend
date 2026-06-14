import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/theme.dart';
import 'tracing_exercise_screen.dart';

/// Browse screen for stand-alone tracing practice.
///
/// Organised into three sections: Arabic letters, English letters, and
/// numbers 0–9.  Tapping any tile navigates to [TracingExerciseScreen]
/// with that character as the [text] argument.
class TracingListScreen extends StatelessWidget {
  final String studentId;

  const TracingListScreen({super.key, required this.studentId});

  // ── Data ──────────────────────────────────────────────────────────────────

  static const _arabicLetters = [
    'أ', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر',
    'ز', 'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ع', 'غ', 'ف',
    'ق', 'ك', 'ل', 'م', 'ن', 'ه', 'و', 'ي',
  ];

  static const _englishLetters = [
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j',
    'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't',
    'u', 'v', 'w', 'x', 'y', 'z',
  ];

  static const _numbers = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
  ];

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _openExercise(BuildContext context, String char) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TracingExerciseScreen(
        questionId: char,
        studentId: studentId,
        text: char,
      ),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          AppStrings.tracingTitle,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildSection(
                  context,
                  title: 'الحروف العربية',
                  color: AppColors.purple,
                  chars: _arabicLetters,
                ),
                _buildSection(
                  context,
                  title: 'الحروف الإنجليزية',
                  color: AppColors.secondary,
                  chars: _englishLetters,
                ),
                _buildSection(
                  context,
                  title: 'الأرقام',
                  color: AppColors.primary,
                  chars: _numbers,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: const Text(
        AppStrings.tracingBanner,
        style: TextStyle(color: Colors.white70, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ── Section ───────────────────────────────────────────────────────────────

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Color color,
    required List<String> chars,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: chars.length,
            itemBuilder: (ctx, i) =>
                _CharTile(char: chars[i], color: color, onTap: () => _openExercise(ctx, chars[i])),
          ),
        ],
      ),
    );
  }
}

// ── Tile widget ────────────────────────────────────────────────────────────────

class _CharTile extends StatelessWidget {
  const _CharTile({
    required this.char,
    required this.color,
    required this.onTap,
  });

  final String char;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shadowColor: color.withValues(alpha: 0.20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, color.withValues(alpha: 0.07)],
            ),
          ),
          child: Center(
            child: Text(
              char,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
