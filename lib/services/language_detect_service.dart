import 'dart:async';
import 'package:flutter_langdetect/flutter_langdetect.dart' as langdetect;
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';

class LanguageDetectResult {
  final String code;
  final double probability;

  const LanguageDetectResult({required this.code, required this.probability});
}

class LanguageDetectService {
  LanguageDetectService._();
  static final LanguageDetectService instance = LanguageDetectService._();

  //google_mlkit_language_id
  late final LanguageIdentifier languageIdentifier;

  Timer? _debounce;

  Future<void> initialize() async {
    try {
      //google_mlkit_language_id
      languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.1);

      //flutter_langdetect
      await langdetect.initLangDetect();
    } catch (_) {
      // 일부 환경에서 별도 초기화가 필요 없을 수 있음
    }
  }

  void dispose() {
    _debounce?.cancel();
    try {
      languageIdentifier.close();
    } catch (_) {}
  }

  void detectRealtime({
    required String text,
    Duration debounce = const Duration(milliseconds: 220),
    required void Function(LanguageDetectResult result) onDetected,
    void Function(Object error)? onError,
  }) {
    _debounce?.cancel();
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _debounce = Timer(debounce, () {
      _detectRealtimeImpl(
        text: trimmed,
        onDetected: onDetected,
        onError: onError,
      );
    });
  }

  void detectRealtimeAll({
    required String text,
    Duration debounce = const Duration(milliseconds: 220),
    required void Function(List<LanguageDetectResult> results) onDetected,
    void Function(Object error)? onError,
  }) {
    _debounce?.cancel();
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _debounce = Timer(debounce, () {
      _detectRealtimeAllImpl(
        text: trimmed,
        onDetected: onDetected,
        onError: onError,
      );
    });
  }

  Future<void> _detectRealtimeImpl({
    required String text,
    required void Function(LanguageDetectResult result) onDetected,
    void Function(Object error)? onError,
  }) async {
    if (_isHanjaDominant(text)) {
      onDetected(const LanguageDetectResult(code: 'zh', probability: 1.0));
      return;
    }
    try {
      // 1) ML Kit 우선
      final List<IdentifiedLanguage> langs = await languageIdentifier
          .identifyPossibleLanguages(text);
      final List<LanguageDetectResult> mlResults = langs
          .where((l) => (l.languageTag.isNotEmpty && l.languageTag != 'und'))
          .map(
            (l) => LanguageDetectResult(
              code: l.languageTag,
              probability: l.confidence.toDouble(),
            ),
          )
          .toList();
      if (mlResults.isNotEmpty) {
        // 최상위 후보
        onDetected(mlResults.first);
        return;
      }
    } catch (e) {
      // ML Kit 실패 시 폴백
    }

    try {
      // 2) flutter_langdetect 폴백
      final List<dynamic> candidates = langdetect.detectLangs(text);
      if (candidates.isNotEmpty) {
        final dynamic best = candidates.first;
        final String code = _extractLangCode(best);
        final double prob = _extractProb(best);
        if (code.isNotEmpty) {
          onDetected(LanguageDetectResult(code: code, probability: prob));
          return;
        }
      }
      final String code = langdetect.detect(text);
      onDetected(LanguageDetectResult(code: code, probability: 0.0));
    } catch (e) {
      if (onError != null) onError(e);
    }
  }

  Future<void> _detectRealtimeAllImpl({
    required String text,
    required void Function(List<LanguageDetectResult> results) onDetected,
    void Function(Object error)? onError,
  }) async {
    if (_isHanjaDominant(text)) {
      print('한자 우선 (여러 후보)');
      onDetected(const [LanguageDetectResult(code: 'zh', probability: 1.0)]);
      return;
    }
    try {
      print('ML Kit 우선 (여러 후보)');
      // 1) ML Kit 우선 (여러 후보)
      final List<IdentifiedLanguage> langs = await languageIdentifier
          .identifyPossibleLanguages(text);

      final List<LanguageDetectResult> mlResults = langs
          .where((l) => (l.languageTag.isNotEmpty && l.languageTag != 'und'))
          .map(
            (l) => LanguageDetectResult(
              code: l.languageTag,
              probability: l.confidence.toDouble(),
            ),
          )
          .toList();

      if (mlResults.isNotEmpty) {
        onDetected(mlResults);
        return;
      }
    } catch (e) {
      print('ML Kit 실패 (여러 후보): $e');
      // ML Kit 실패 시 폴백
    }

    try {
      print('flutter_langdetect 폴백 (여러 후보)');
      // 2) flutter_langdetect 폴백 (여러 후보)
      final List<dynamic> candidates = langdetect.detectLangs(text);
      if (candidates.isNotEmpty) {
        final List<LanguageDetectResult> results = candidates
            .map(
              (c) => LanguageDetectResult(
                code: _extractLangCode(c),
                probability: _extractProb(c),
              ),
            )
            .where((r) => r.code.isNotEmpty)
            .toList(growable: false);
        if (results.isNotEmpty) {
          onDetected(results);
          return;
        }
      }
      final String fallback = langdetect.detect(text);
      onDetected([LanguageDetectResult(code: fallback, probability: 0.0)]);
    } catch (e) {
      print('flutter_langdetect 실패 (여러 후보): $e');
      if (onError != null) onError(e);
    }
  }

  String _extractLangCode(dynamic item) {
    try {
      final dynamic byField = (item as dynamic).lang;
      if (byField is String) return byField;
    } catch (_) {}
    try {
      if (item is Map) {
        final dynamic v = item['lang'];
        if (v is String) return v;
      }
    } catch (_) {}
    return '';
  }

  double _extractProb(dynamic item) {
    try {
      final dynamic byField = (item as dynamic).prob;
      if (byField is num) return byField.toDouble();
    } catch (_) {}
    try {
      if (item is Map) {
        final dynamic v = item['prob'];
        if (v is num) return v.toDouble();
      }
    } catch (_) {}
    return 0.0;
  }

  bool _isHanjaDominant(String text, {double threshold = 0.5}) {
    final double ratio = _hanCoverageRatio(text);
    return ratio >= threshold;
  }

  double _hanCoverageRatio(String text) {
    int total = 0;
    int han = 0;
    for (final codePoint in text.runes) {
      if (_isWhitespaceCodePoint(codePoint)) continue;
      total++;
      if (_isHanCodePoint(codePoint)) han++;
    }
    if (total == 0) return 0.0;
    return han / total;
  }

  bool _isWhitespaceCodePoint(int cp) {
    return cp == 0x20 ||
        cp == 0x09 ||
        cp == 0x0A ||
        cp == 0x0D ||
        cp == 0x0B ||
        cp == 0x0C;
  }

  bool _isHanCodePoint(int cp) {
    if (cp >= 0x4E00 && cp <= 0x9FFF) return true;
    if (cp >= 0x3400 && cp <= 0x4DBF) return true;
    if (cp >= 0xF900 && cp <= 0xFAFF) return true;
    return false;
  }
}
