import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../services/api_client.dart';

// ─────────────────────────────────────────────────────────────
// VoiceService
//
// Uses the project's existing ApiClient (http-based singleton).
// No Dio, no Riverpod required.
// ─────────────────────────────────────────────────────────────
class VoiceService {
  VoiceService._();
  static final instance = VoiceService._();

  final _api = ApiClient.instance;
  final _player = AudioPlayer();
  final _recorder = AudioRecorder();

  String? _recordingPath;

  // ── TTS: play backend-generated audio ─────────────────────
  //
  // POST /api/audio/lesson/{lessonId}/narrate  or  /api/audio/question/{id}/read
  // already returns an audioUrl — call those via LessonService.
  //
  // This method is for any ad-hoc text (e.g. reading a quiz question aloud).
  // Backend must expose POST /api/audio/tts with body {text, language}.
  // Response: { data: { audioUrl: "..." } }  OR  { data: { audio_base64: "..." } }

  Future<void> speak(String text, {String language = 'ar'}) async {
    try {
      await _player.stop();

      final res = await _api.post('/api/audio/tts', {
        'text': text,
        'language': language,
      });

      final data = res['data'] as Map<String, dynamic>? ?? {};

      // ── Option A: backend returns a URL ───────────────────
      final audioUrl = data['audioUrl'] as String?;
      if (audioUrl != null && audioUrl.isNotEmpty) {
        await _player.play(UrlSource(audioUrl));
        return;
      }

      // ── Option B: backend returns base64-encoded bytes ────
      final b64 = data['audio_base64'] as String?;
      if (b64 != null && b64.isNotEmpty) {
        final bytes = base64Decode(b64);
        await _player.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
      }
    } catch (_) {
      // Fail silently — audio is non-critical
    }
  }

  // ── Play any audio URL (e.g. from LessonService.narrateLesson) ──
  Future<void> playUrl(String url) async {
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (_) {}
  }

  Future<void> stopAudio() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  // ── Microphone permission ─────────────────────────────────

  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> hasMicPermission() async =>
      await Permission.microphone.status == PermissionStatus.granted;

  // ── Recording ─────────────────────────────────────────────

  Future<bool> startRecording() async {
    // Check / request mic permission
    if (!await _recorder.hasPermission()) {
      final granted = await requestMicPermission();
      if (!granted) return false;
    }

    final dir = await getTemporaryDirectory();
    _recordingPath =
        '${dir.path}/kidlearn_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: _recordingPath!,
    );
    return true;
  }

  // ── STT: stop recording and transcribe ────────────────────
  //
  // Uses your backend: POST /api/quiz/attempt/{attemptId}/voice-answer
  // expects multipart field "audio" + query params questionId & language.
  //
  // For a standalone transcription (no attempt context), calls
  // a simpler endpoint: POST /api/audio/stt  with field "audio".
  // Backend returns { data: { text: "..." } }

  Future<String?> stopAndTranscribe({String language = 'ar'}) async {
    final path = await _recorder.stop();
    final filePath = path ?? _recordingPath;
    if (filePath == null) return null;

    final file = File(filePath);
    if (!await file.exists()) return null;

    try {
      // POST /api/audio/stt   (standalone transcription endpoint)
      // Adjust the path/field name if your backend differs.
      final res = await _api.postMultipart(
        '/api/audio/stt',
        fileField: 'audio',
        file: file,
        filename: 'audio.m4a',
        mimeType: 'audio/m4a',
        fields: {'language': language},
      );

      final data = res['data'] as Map<String, dynamic>? ?? {};
      return data['text'] as String?;
    } catch (_) {
      return null;
    } finally {
      // Clean up temp file
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  // ── Voice answer for a specific quiz attempt ──────────────
  //
  // POST /api/quiz/attempt/{attemptId}/voice-answer
  // multipart: field "audio" + params questionId, language

  Future<String?> stopAndTranscribeForQuiz({
    required int attemptId,
    required int questionId,
    String language = 'ar',
  }) async {
    final path = await _recorder.stop();
    final filePath = path ?? _recordingPath;
    if (filePath == null) return null;

    final file = File(filePath);
    if (!await file.exists()) return null;

    try {
      final res = await _api.postMultipart(
        '/api/quiz/attempt/$attemptId/voice-answer'
        '?questionId=$questionId&language=$language',
        fileField: 'audio',
        file: file,
        filename: 'audio.m4a',
        mimeType: 'audio/m4a',
      );

      final data = res['data'] as Map<String, dynamic>? ?? {};
      // Backend returns SubmitAnswerResponse — extract transcribed text
      return data['spokenText'] as String? ?? data['answer'] as String?;
    } catch (_) {
      return null;
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  // ── Cleanup ───────────────────────────────────────────────

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
