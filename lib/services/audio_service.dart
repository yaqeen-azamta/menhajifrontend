// ════════════════════════════════════════════════════════════════════════════
// audio_service.dart — Backend-powered TTS audio service
//
// Workflow:
//   speak(text, type) → POST /api/audio/speak → audioUrl → audioplayers
//
// The backend uses Microsoft Edge TTS (ar-SA-ZariyahNeural / ar-SA-HamedNeural)
// and caches generated audio on disk. Subsequent calls with the same text+type
// return instantly from the cache.
//
// All errors are caught silently so TTS never blocks the quiz or lesson flow.
// ════════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

class AudioService {
  AudioService._();
  static final instance = AudioService._();

  final _player = AudioPlayer();
  final _api = ApiClient.instance;

  bool _playing = false;
  StreamSubscription<void>? _completionSub;

  bool get isPlaying => _playing;

  // ── Speak ─────────────────────────────────────────────────────────────────
  //
  // text      : Text to synthesize (Arabic or English, auto-detected by backend)
  // type      : Content-type hint passed to backend for voice style selection:
  //               welcome | motivation | hint | explanation | general
  // onPlaybackEnd : Called when audio finishes naturally (NOT called on stop()).

  Future<void> speak(
    String text, {
    String type = 'general',
    VoidCallback? onPlaybackEnd,
  }) async {
    if (text.isEmpty) return;
    try {
      // Cancel any current playback before starting a new one.
      await _stop();

      final res = await _api.post('/api/audio/speak', {
        'text': text,
        'type': type,
      });

      final data = res['data'] as Map<String, dynamic>? ?? {};
      final audioUrl = data['audioUrl'] as String?;
      if (audioUrl == null || audioUrl.isEmpty) return;

      final normalizedAudioUrl = audioUrl.startsWith('/')
          ? audioUrl.substring(1)
          : audioUrl;

      final fullUrl = audioUrl.startsWith('http')
          ? audioUrl
          : '$kBaseUrl/$normalizedAudioUrl';

      debugPrint('====================');
      debugPrint('kBaseUrl = $kBaseUrl');
      debugPrint('audioUrl = $audioUrl');
      debugPrint('normalizedAudioUrl = $normalizedAudioUrl');
      debugPrint('fullUrl = $fullUrl');
      debugPrint('====================');

      _playing = true;

      // Register completion listener before play() so we don't miss it.
      _completionSub = _player.onPlayerComplete.listen((_) {
        _playing = false;
        _completionSub?.cancel();
        _completionSub = null;
        onPlaybackEnd?.call();
      });

      await _player.play(UrlSource(fullUrl));
    } catch (_) {
      _playing = false;
      _completionSub?.cancel();
      _completionSub = null;
      // Fail silently — audio is non-critical.
    }
  }

  // ── Stop ──────────────────────────────────────────────────────────────────

  Future<void> stop() async {
    await _stop();
  }

  Future<void> _stop() async {
    _completionSub?.cancel();
    _completionSub = null;
    try {
      await _player.stop();
    } catch (_) {}
    _playing = false;
  }

  // ── Play a URL directly (e.g. from lesson narrate) ────────────────────────

  Future<void> playUrl(String url) async {
    try {
      await _stop();
      await _player.play(UrlSource(url));
    } catch (_) {}
  }

  void dispose() {
    _completionSub?.cancel();
    _player.dispose();
  }
}
