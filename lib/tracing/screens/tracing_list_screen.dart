import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/theme.dart';
import '../models/tracing_question.dart';
import '../utils/tracing_templates.dart';
import 'tracing_exercise_screen.dart';

/// Grid of all available tracing exercises, grouped by category chip.
class TracingListScreen extends StatelessWidget {
  final String studentId;

  const TracingListScreen({super.key, required this.studentId});

  static const _questions = TracingTemplates.all;

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
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
              ),
              itemCount: _questions.length,
              itemBuilder: (ctx, i) => _QuestionCard(
                question: _questions[i],
                onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => TracingExerciseScreen(
                    question: _questions[i],
                    studentId: studentId,
                    initialIndex: i,
                    allQuestions: _questions,
                  ),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: const Text(
        AppStrings.tracingBanner,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Card widget ───────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final TracingQuestion question;
  final VoidCallback onTap;

  const _QuestionCard({required this.question, required this.onTap});

  Color get _color => switch (question.category) {
        TracingCategory.number => AppColors.primary,
        TracingCategory.englishLetter => AppColors.secondary,
        TracingCategory.arabicLetter => AppColors.purple,
        TracingCategory.shape => AppColors.gold,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 5,
        shadowColor: _color.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                _color.withValues(alpha: 0.06),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Big character display
              Text(
                question.displayText,
                style: TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.bold,
                  color: _color,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              // Category chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  question.categoryLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _color,
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