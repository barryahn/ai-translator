import 'package:flutter_tts/flutter_tts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'language_service.dart';
import 'dart:async';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;
  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();
  final StreamController<TtsProgress> _progressController =
      StreamController<TtsProgress>.broadcast();

  Stream<bool> get speakingStream => _speakingController.stream;
  bool get isSpeaking => _isSpeaking;
  Stream<TtsProgress> get progressStream => _progressController.stream;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
    try {
      _tts.setStartHandler(() {
        _isSpeaking = true;
        _speakingController.add(true);
      });
    } catch (_) {}
    try {
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _speakingController.add(false);
      });
    } catch (_) {}
    try {
      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _speakingController.add(false);
      });
    } catch (_) {}
    try {
      _tts.setProgressHandler((String text, int start, int end, String word) {
        _progressController.add(
          TtsProgress(text: text, start: start, end: end, word: word),
        );
      });
    } catch (_) {}
    _initialized = true;
  }

  String _mapToTtsLanguage(String code) {
    final normalized = code.trim().toLowerCase();
    switch (normalized) {
      case 'ko':
        return 'ko-KR';
      case 'en':
        return 'en-US';
      case 'ja':
        return 'ja-JP';
      case 'zh-tw':
        return 'zh-TW';
      case 'zh':
      case 'zh-cn':
        return 'zh-CN';
      case 'fr':
        return 'fr-FR';
      case 'de':
        return 'de-DE';
      case 'es':
        return 'es-ES';
      default:
        return 'en-US';
    }
  }

  Future<void> speak(String text, {required String uiLanguage}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _ensureInit();

    final String code = LanguageService.getLanguageCodeFromUi(uiLanguage);
    String ttsLang = _mapToTtsLanguage(code);

    try {
      final dynamic available = await _tts.isLanguageAvailable(ttsLang);
      if (available != true) {
        ttsLang = 'en-US';
      }
    } catch (_) {}

    try {
      await _tts.setLanguage(ttsLang);
    } catch (_) {}
    try {
      await _tts.setSpeechRate(0.45);
    } catch (_) {}
    try {
      await _tts.setVolume(1.0);
    } catch (_) {}
    try {
      await _tts.setPitch(1.0);
    } catch (_) {}

    try {
      await _tts.stop();
    } catch (_) {}

    _isSpeaking = true;
    _speakingController.add(true);
    try {
      await _tts.speak(trimmed);
    } catch (e) {
      _isSpeaking = false;
      _speakingController.add(false);
      print('TTS 초기화 오류: ${e.runtimeType}');
      Fluttertoast.showToast(msg: '재생 중 오류가 발생했습니다');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _isSpeaking = false;
    _speakingController.add(false);
  }
}

class TtsProgress {
  final String text;
  final int start;
  final int end;
  final String? word;

  TtsProgress({
    required this.text,
    required this.start,
    required this.end,
    this.word,
  });
}
