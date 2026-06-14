import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../services/api_client.dart';
import '../services/lesson_service.dart';
import '../theme/theme.dart';
import '../widgets/fat_button.dart';
import '../widgets/mic_button.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lessonId});
  final String lessonId;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  LessonDetailModel? _lesson;
  bool _loading = true;
  String? _error;
  int _step = 0;
  String? _transcript;
  bool _loadingAudio = false;

  final _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadLesson() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final id = int.tryParse(widget.lessonId);
    if (id == null) {
      setState(() {
        _error =
            'Invalid lesson ID "${widget.lessonId}".\nPlease go back and select a lesson.';
        _loading = false;
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getInt('active_student_id');
      debugPrint('LessonScreen: loading lesson id=$id studentId=$studentId');
      final lesson = await LessonService.instance.getLessonDetail(id, studentId: studentId);
      setState(() => _lesson = lesson);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Resolves a potentially relative path from the backend into a full URL.
  String _resolveAudioUrl(String raw) {
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '$kBaseUrl$raw';
  }

  Future<void> _playAudio() async {
    final l = _lesson;
    final id = int.tryParse(widget.lessonId);
    if (l == null || id == null) return;

    // If the lesson already has a cached audioUrl, play it directly.
    if (l.audioUrl != null && l.audioUrl!.isNotEmpty) {
      await _startPlayback(_resolveAudioUrl(l.audioUrl!));
      return;
    }

    // Otherwise ask the backend to narrate on-demand.
    setState(() => _loadingAudio = true);
    try {
      final relativeUrl = await LessonService.instance.narrateLesson(id);
      if (relativeUrl != null && relativeUrl.isNotEmpty) {
        await _startPlayback(_resolveAudioUrl(relativeUrl));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.lessonAudioNotAvailable)),
        );
      }
    } catch (e) {
      debugPrint('LessonScreen._playAudio error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.lessonAudioFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAudio = false);
    }
  }

  Future<void> _startPlayback(String url) async {
    debugPrint('LessonScreen: playing audio → $url');
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('LessonScreen._startPlayback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.lessonAudioFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _lesson == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('😕', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  _error ?? AppStrings.lessonNotFound,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                FatButton(
                  label: AppStrings.goBack,
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final l = _lesson!;
    final subjectKey = _subjectKey(l.subjectName);

    final steps = [
      (AppStrings.lessonStepWelcomeTitle,
        AppStrings.lessonStepWelcomeBody(l.title, l.objectives ?? '')),
      (AppStrings.lessonStepLearnTitle, l.content),
      (AppStrings.lessonStepSpeakTitle, AppStrings.lessonStepSpeakBody),
    ];

    final cur = steps[_step];
    final progress = (_step + 1) / steps.length;
    final (bg, sh) = SubjectColors.of(subjectKey);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // TOP NAV
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 14,
                        backgroundColor: const Color(0xFFE8DCC8),
                        color: bg,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                        border: Border(bottom: BorderSide(color: sh, width: 6)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _subjectEmoji(subjectKey),
                        style: const TextStyle(fontSize: 56),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      l.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      cur.$1.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Content card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFE8DCC8),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cur.$2,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Tap to hear
                          GestureDetector(
                            onTap: _loadingAudio ? null : _playAudio,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _loadingAudio
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.volume_up_rounded,
                                          color: AppColors.secondary,
                                          size: 20,
                                        ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    AppStrings.lessonTapToHear,
                                    style: TextStyle(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Speaking step
                    if (_step == 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          children: [
                            MicButton(
                              onTranscript: (t) =>
                                  setState(() => _transcript = t),
                            ),
                            if (_transcript != null &&
                                _transcript != '__no_permission__')
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFFFD299),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    AppStrings.lessonYouSaid(_transcript!),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            if (_transcript == '__no_permission__')
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                  AppStrings.lessonMicPermission,
                                  style: TextStyle(
                                    color: AppColors.flame,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // BOTTOM BUTTON
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFEAEAEA), width: 2),
                ),
              ),
              child: FatButton(
                label: _step < steps.length - 1
                    ? AppStrings.continueBtn
                    : AppStrings.lessonViewQuestions,
                onPressed: () {
                  if (_step < steps.length - 1) {
                    setState(() => _step++);
                  } else {
                    // Push so the back button on question_screen returns here
                    context.push('/questions/${l.id}');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subjectKey(String name) {
    final n = name.toLowerCase();
    if (n.contains('math') || n.contains('رياض')) return 'math';
    if (n.contains('read') ||
        n.contains('arabic') ||
        n.contains('عرب') ||
        n.contains('english')) {
      return 'reading';
    }
    if (n.contains('science') || n.contains('علوم')) return 'science';
    return 'math';
  }

  String _subjectEmoji(String key) {
    switch (key) {
      case 'reading':
        return '📚';
      case 'science':
        return '🌱';
      default:
        return '➕';
    }
  }
}
