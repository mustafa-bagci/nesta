import 'package:flutter_tts/flutter_tts.dart';

/// Sesli uyarıları okuyan arayüz (testlerde sahte uygulama kullanılır).
abstract class Speaker {
  Future<void> init({required double rate});

  /// [interrupt] true ise konuşmakta olan cümle kesilir (güvenlik uyarıları).
  Future<void> say(String text, {bool interrupt = false});
  Future<void> stop();
  Future<void> dispose();
}

/// Cihazın metin okuma motoruyla Türkçe sesli koç.
class VoiceCoach implements Speaker {
  VoiceCoach({this.enabled = true});

  final bool enabled;
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;
  DateTime? _lastStartedAt;

  @override
  Future<void> init({required double rate}) async {
    if (!enabled) return;
    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(rate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(false);
      _tts.setStartHandler(() => _speaking = true);
      _tts.setCompletionHandler(() => _speaking = false);
      _tts.setCancelHandler(() => _speaking = false);
      _tts.setErrorHandler((_) => _speaking = false);
    } catch (_) {
      // Metin okuma motoru yoksa sessiz devam edilir; uyarılar ekranda da gösterilir.
    }
  }

  @override
  Future<void> say(String text, {bool interrupt = false}) async {
    if (!enabled) return;
    final recentlyStarted =
        _lastStartedAt != null &&
        DateTime.now().difference(_lastStartedAt!) < const Duration(seconds: 6);
    if (_speaking && recentlyStarted && !interrupt) return;
    try {
      if (interrupt || _speaking) await _tts.stop();
      _lastStartedAt = DateTime.now();
      _speaking = true;
      await _tts.speak(text);
    } catch (_) {
      _speaking = false;
    }
  }

  @override
  Future<void> stop() async {
    if (!enabled) return;
    try {
      await _tts.stop();
    } catch (_) {}
    _speaking = false;
  }

  @override
  Future<void> dispose() => stop();
}
