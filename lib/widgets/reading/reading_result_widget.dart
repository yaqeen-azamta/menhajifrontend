import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/reading_service.dart';
import '../../theme/theme.dart';

// ─────────────────────────────────────────────────────────────
// Word status
// ─────────────────────────────────────────────────────────────

enum _WordStatus { correct, incorrect, missing, neutral }

// Strip Arabic and common punctuation before matching so that
// "الكتاب،" matches "الكتاب" in the word lists returned by the backend.
final _punctuationRe = RegExp(r'[،.؟!:;,\-،؛]');

_WordStatus _statusOf(String rawWord, ReadingAssessmentResult result) {
  final clean = rawWord.replaceAll(_punctuationRe, '').trim();
  if (clean.isEmpty) return _WordStatus.neutral;

  if (result.correctWords.any((w) => w.trim() == clean)) {
    return _WordStatus.correct;
  }
  if (result.incorrectWords.any((w) => w.trim() == clean)) {
    return _WordStatus.incorrect;
  }
  if (result.missingWords.any((w) => w.trim() == clean)) {
    return _WordStatus.missing;
  }
  return _WordStatus.neutral;
}

// ─────────────────────────────────────────────────────────────
// Color palette (file-level so all widgets share it)
// ─────────────────────────────────────────────────────────────

const _correctBg   = Color(0xFFE8F5E9);
const _correctFg   = Color(0xFF2E7D32);
const _incorrectBg = Color(0xFFFFEBEE);
const _incorrectFg = Color(0xFFC62828);
const _missingBg   = Color(0xFFFFF3E0);
const _missingFg   = Color(0xFFE65100);
const _neutralBg   = Color(0xFFF5F5F5);

// ─────────────────────────────────────────────────────────────
// ReadingResultWidget
//
// Displays the original paragraph word-by-word with colour coding:
//   green  = correct word
//   red    = incorrect word (wrong letters highlighted inside the chip)
//   orange = missing word (present in original, not spoken)
//
// Also shows:
//   • _LetterAnalysisSection — wrongLetters / missingLetters / extraLetters
//     as colour-coded chips with Arabic per-letter tips
//   • "What was heard" section with the raw recognised text
// ─────────────────────────────────────────────────────────────

class ReadingResultWidget extends StatelessWidget {
  const ReadingResultWidget({super.key, required this.result});

  final ReadingAssessmentResult result;

  @override
  Widget build(BuildContext context) {
    debugPrint('[RESULT BUILD] ReadingResultWidget.build — originalText="${result.originalText}" correctWords=${result.correctWords.length} incorrectWords=${result.incorrectWords.length}');
    final words = result.originalText
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();

    // Pre-compute the wrong-letter set once and share with every chip.
    final wrongLetterSet = Set<String>.unmodifiable(result.wrongLetters);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Section header ────────────────────────────────
        const Text(
          AppStrings.readingResultTitle,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),

        // ── Colour legend ─────────────────────────────────
        _Legend(),
        const SizedBox(height: 14),

        // ── Word chips ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 8,
            children: words
                .map((w) => _WordChip(
                      word: w,
                      status: _statusOf(w, result),
                      wrongLetterSet: wrongLetterSet,
                    ))
                .toList(),
          ),
        ),

        // ── Character-level analysis ──────────────────────
        const SizedBox(height: 16),
        _LetterAnalysisSection(result: result),

        // ── "What was heard" section ──────────────────────
        if (result.recognizedText.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            AppStrings.readingRecognizedLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
            ),
            child: Text(
              result.recognizedText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.7,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _LetterAnalysisSection
//
// Shows three rows of letter chips (wrong / missing / extra) and a
// character-level feedback message.
// Hidden entirely when all three lists are empty (perfect pronunciation).
// ─────────────────────────────────────────────────────────────

class _LetterAnalysisSection extends StatelessWidget {
  const _LetterAnalysisSection({required this.result});

  final ReadingAssessmentResult result;

  @override
  Widget build(BuildContext context) {
    final hasWrong    = result.wrongLetters.isNotEmpty;
    final hasMissing  = result.missingLetters.isNotEmpty;
    final hasExtra    = result.extraLetters.isNotEmpty;
    final hasFeedback = result.characterFeedback.isNotEmpty;

    if (!hasWrong && !hasMissing && !hasExtra) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: const [
              Icon(Icons.manage_search_rounded,
                  size: 18, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text(
                AppStrings.readingLetterAnalysisTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Wrong letters — substituted (mispronounced as a different letter)
          if (hasWrong) ...[
            _LetterRow(
              label: AppStrings.readingWrongLettersLabel,
              letters: result.wrongLetters,
              chipColor: _incorrectFg,
              chipBg: _incorrectBg,
            ),
            const SizedBox(height: 10),
          ],

          // Missing letters — omitted entirely
          if (hasMissing) ...[
            _LetterRow(
              label: AppStrings.readingMissingLettersLabel,
              letters: result.missingLetters,
              chipColor: _missingFg,
              chipBg: _missingBg,
            ),
            const SizedBox(height: 10),
          ],

          // Extra letters — sounds added by the student
          if (hasExtra) ...[
            _LetterRow(
              label: AppStrings.readingExtraLettersLabel,
              letters: result.extraLetters,
              chipColor: const Color(0xFF1565C0),
              chipBg: const Color(0xFFE3F2FD),
            ),
            const SizedBox(height: 10),
          ],

          // Per-letter Arabic tips from the backend
          if (hasFeedback) ...[
            const Divider(height: 18, thickness: 1, color: Color(0xFFEEEEEE)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡 ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Text(
                    result.characterFeedback,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _LetterRow  — label + horizontal list of letter chips
// ─────────────────────────────────────────────────────────────

class _LetterRow extends StatelessWidget {
  const _LetterRow({
    required this.label,
    required this.letters,
    required this.chipColor,
    required this.chipBg,
  });

  final String label;
  final List<String> letters;
  final Color chipColor;
  final Color chipBg;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: chipColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: letters
                .map((l) => _LetterChip(letter: l, color: chipColor, bg: chipBg))
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _LetterChip — a square chip displaying a single Arabic letter
// ─────────────────────────────────────────────────────────────

class _LetterChip extends StatelessWidget {
  const _LetterChip({
    required this.letter,
    required this.color,
    required this.bg,
  });

  final String letter;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _Legend  — three colour dots with labels
// ─────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: const [
        _LegendItem(
          color: _correctFg,
          bgColor: _correctBg,
          label: AppStrings.readingWordCorrect,
        ),
        _LegendItem(
          color: _incorrectFg,
          bgColor: _incorrectBg,
          label: AppStrings.readingWordIncorrect,
        ),
        _LegendItem(
          color: _missingFg,
          bgColor: _missingBg,
          label: AppStrings.readingWordMissing,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.bgColor,
    required this.label,
  });

  final Color color;
  final Color bgColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _WordChip — a single coloured word token
//
// When [wrongLetterSet] is non-empty and the chip is not for a missing
// word (missing = not spoken, no value in highlighting letters), each
// character in the word is individually checked.  Characters that appear
// in [wrongLetterSet] are rendered with a red highlight using RichText,
// showing the student exactly which letters need attention.
// ─────────────────────────────────────────────────────────────

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    required this.status,
    this.wrongLetterSet = const {},
  });

  final String word;
  final _WordStatus status;

  /// Set of Arabic characters (single-char strings) that were mispronounced.
  final Set<String> wrongLetterSet;

  Color get _bg {
    switch (status) {
      case _WordStatus.correct:
        return _correctBg;
      case _WordStatus.incorrect:
        return _incorrectBg;
      case _WordStatus.missing:
        return _missingBg;
      case _WordStatus.neutral:
        return _neutralBg;
    }
  }

  Color get _fg {
    switch (status) {
      case _WordStatus.correct:
        return _correctFg;
      case _WordStatus.incorrect:
        return _incorrectFg;
      case _WordStatus.missing:
        return _missingFg;
      case _WordStatus.neutral:
        return AppColors.textPrimary;
    }
  }

  Color get _border => _fg.withValues(alpha: 0.40);

  double get _borderWidth => status == _WordStatus.missing ? 2.0 : 1.5;

  Widget _buildText() {
    // Missing words were not spoken — skip letter highlighting.
    if (wrongLetterSet.isEmpty || status == _WordStatus.missing) {
      return Text(
        word,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _fg,
          height: 1.4,
        ),
      );
    }

    final spans = <TextSpan>[];
    for (final rune in word.runes) {
      final char = String.fromCharCode(rune);
      final isWrong = wrongLetterSet.contains(char);
      spans.add(TextSpan(
        text: char,
        style: isWrong
            ? const TextStyle(
                color: _incorrectFg,
                fontWeight: FontWeight.w900,
                backgroundColor: Color(0x44C62828),
              )
            : TextStyle(color: _fg, fontWeight: FontWeight.w700),
      ));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 17,
          height: 1.4,
          fontFamily: 'Nunito',
        ),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border, width: _borderWidth),
      ),
      child: _buildText(),
    );
  }
}
