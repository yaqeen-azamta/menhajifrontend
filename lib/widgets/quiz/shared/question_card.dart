// ════════════════════════════════════════════════════════════════════════════
// question_card.dart — Duolingo-style rounded card with subtle shadow
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAEAEA), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}
