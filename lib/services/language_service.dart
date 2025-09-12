import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

/// main.dart에서 사용하는 모든 언어 관련 로직을 이 서비스에서 관리합니다.
class LanguageService {
  // 저장 키
  static const String _appLanguageKey = 'app_language';
  static const String _tsFromLanguageKey = 'ts_from_language';
  static const String _tsToLanguageKey = 'ts_to_language';

  // 언어 코드 상수
  static const String codeKorean = 'ko';
  static const String codeEnglish = 'en';
  static const String codeJapanese = 'ja';
  static const String codeChineseSimplified = 'zh-CN';
  static const String codeChineseTaiwan = 'zh-TW';
  static const String codeFrench = 'fr';
  static const String codeGerman = 'de';
  static const String codeSpanish = 'es';

  // UI에서 사용하는 언어 이름(한국어 라벨)
  static const String uiKorean = '한국어';
  static const String uiEnglish = '영어';
  static const String uiJapanese = '일본어';
  static const String uiChinese = '중국어';
  static const String uiChineseTaiwan = '대만 중국어';
  static const String uiFrench = '프랑스어';
  static const String uiGerman = '독일어';
  static const String uiSpanish = '스페인어';

  // 기본 from/to (main.dart 기본값과 일치)
  static const String _defaultFrom = uiEnglish;
  static const String _defaultTo = uiKorean;

  static bool _isInitialized = false;

  // 앱 언어(로케일) 코드. 별도 UI에서 사용할 수 있음.
  static String _appLanguageCode = codeKorean;

  // 번역 언어 상태 (UI에서 바인딩해 사용)
  static String _fromLanguage = _defaultFrom;
  static String _toLanguage = _defaultTo;

  // 변경 알림 스트림 (from/to/appLanguage 변경 통지)
  static final StreamController<Map<String, String>> _languageController =
      StreamController<Map<String, String>>.broadcast();

  static Stream<Map<String, String>> get languageStream =>
      _languageController.stream;

  // 초기화: 저장된 값 로드 + 시스템 로케일 기반 기본값 설정
  static Future<void> initialize() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();

    // 앱 언어 코드: 저장된 값 없으면 시스템 로케일로 결정
    final savedAppLang = prefs.getString(_appLanguageKey);
    if (savedAppLang != null) {
      _appLanguageCode = savedAppLang;
    } else {
      final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final langCode = systemLocale.languageCode;
      final countryCode = systemLocale.countryCode;

      if (langCode == 'ko') {
        _appLanguageCode = codeKorean;
      } else if (langCode == 'en') {
        _appLanguageCode = codeEnglish;
      } else if (langCode == 'ja') {
        _appLanguageCode = codeJapanese;
      } else if (langCode == 'zh' && countryCode == 'TW') {
        _appLanguageCode = codeChineseTaiwan;
      } else if (langCode == 'zh') {
        _appLanguageCode = codeChineseSimplified;
      } else if (langCode == 'fr') {
        _appLanguageCode = codeFrench;
      } else if (langCode == 'de') {
        _appLanguageCode = codeGerman;
      } else if (langCode == 'es') {
        _appLanguageCode = codeSpanish;
      } else {
        _appLanguageCode = codeEnglish;
      }
      await prefs.setString(_appLanguageKey, _appLanguageCode);
    }

    // 번역 from/to: 저장된 값 없으면 main.dart와 동일 기본값 사용
    _fromLanguage = prefs.getString(_tsFromLanguageKey) ?? _defaultFrom;
    _toLanguage = prefs.getString(_tsToLanguageKey) ?? _defaultTo;

    _isInitialized = true;
  }

  // 앱 언어 코드 (예: 'ko','en','zh-TW' 등)
  static String get appLanguageCode => _appLanguageCode;

  static Future<void> setAppLanguageCode(String code) async {
    if (!getSupportedAppLanguageCodes().contains(code)) return;
    _appLanguageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appLanguageKey, code);
    _languageController.add({'appLanguage': code});
  }

  // from/to 언어 (UI 라벨 기준: 한국어/영어/일본어/중국어/대만 중국어/프랑스어/독일어/스페인어)
  static String get fromLanguage => _fromLanguage;
  static String get toLanguage => _toLanguage;

  static Future<void> setTranslationLanguages({
    String? fromLanguage,
    String? toLanguage,
  }) async {
    if (fromLanguage == null && toLanguage == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (fromLanguage != null) {
      _fromLanguage = fromLanguage;
      await prefs.setString(_tsFromLanguageKey, _fromLanguage);
    }
    if (toLanguage != null) {
      _toLanguage = toLanguage;
      await prefs.setString(_tsToLanguageKey, _toLanguage);
    }
    _languageController.add({
      'fromLanguage': _fromLanguage,
      'toLanguage': _toLanguage,
    });
  }

  static Future<void> swapTranslationLanguages() async {
    await setTranslationLanguages(
      fromLanguage: _toLanguage,
      toLanguage: _fromLanguage,
    );
  }

  // main.dart의 _mapUiLanguageToApi와 동일한 역할을 제공
  static String mapUiLanguageToApi(String uiLanguage) {
    switch (uiLanguage) {
      case uiKorean:
        return '한국어';
      case uiEnglish:
        return '영어';
      case uiJapanese:
        return '일본어';
      case uiChinese:
        return '중국어 간체';
      case uiChineseTaiwan:
        return '중국어 번체(대만)';
      case uiFrench:
        return '프랑스어';
      case uiGerman:
        return '독일어';
      case uiSpanish:
        return '스페인어';
      default:
        return uiLanguage;
    }
  }

  // UI에서 사용할 언어 목록 (main.dart의 리스트와 동일 순서)
  static List<String> get uiLanguages => const [
    uiKorean,
    uiEnglish,
    uiJapanese,
    uiChinese,
    uiChineseTaiwan,
    uiFrench,
    uiGerman,
    uiSpanish,
  ];

  // 시스템 로케일을 반영하여 사용자 언어를 앞으로 정렬한 목록
  static List<String> getUiLanguagesOrderedBySystem() {
    final system = WidgetsBinding.instance.platformDispatcher.locale;
    final user = _uiNameFromSystemLocale(system);
    if (user == null) return List<String>.from(uiLanguages);
    final list = <String>[user];
    for (final lang in uiLanguages) {
      if (lang != user) list.add(lang);
    }
    return list;
  }

  // UI 라벨 -> ISO 코드
  static String getLanguageCodeFromUi(String uiLanguage) {
    switch (uiLanguage) {
      case uiKorean:
        return codeKorean;
      case uiEnglish:
        return codeEnglish;
      case uiJapanese:
        return codeJapanese;
      case uiChinese:
        return codeChineseSimplified;
      case uiChineseTaiwan:
        return codeChineseTaiwan;
      case uiFrench:
        return codeFrench;
      case uiGerman:
        return codeGerman;
      case uiSpanish:
        return codeSpanish;
      default:
        return codeEnglish;
    }
  }

  // ISO 코드/로케일 코드 -> UI 라벨 (중복 case 경고 방지를 위해 정규화 후 분기)
  static String getUiLanguageFromCode(String code) {
    final normalized = code.trim().toLowerCase();
    switch (normalized) {
      case 'ko':
        return uiKorean;
      case 'en':
        return uiEnglish;
      case 'ja':
        return uiJapanese;
      case 'zh-tw':
        return uiChineseTaiwan;
      case 'zh':
      case 'zh-cn':
        return uiChinese;
      case 'fr':
        return uiFrench;
      case 'de':
        return uiGerman;
      case 'es':
        return uiSpanish;
      default:
        return uiEnglish;
    }
  }

  // 앱에서 지원하는 로케일 목록 (MaterialApp.supportedLocales에 대응)
  static List<Locale> getSupportedAppLocales() => const [
    Locale('ko'),
    Locale('en'),
    Locale('zh'),
    Locale('fr'),
    Locale('es'),
    Locale.fromSubtags(languageCode: 'zh', countryCode: 'TW'),
  ];

  static List<String> getSupportedAppLanguageCodes() => const [
    codeKorean,
    codeEnglish,
    'zh',
    codeFrench,
    codeSpanish,
    codeChineseTaiwan,
  ];

  // 앱 언어 목록(코드/표시명)을 로컬라이즈해서 제공
  static List<Map<String, String>> getLocalizedAppLanguages(
    AppLocalizations loc,
  ) {
    return [
      {'code': codeKorean, 'name': loc.korean},
      {'code': codeEnglish, 'name': loc.english},
      {'code': 'zh', 'name': loc.chinese},
      {'code': codeChineseTaiwan, 'name': loc.taiwanMandarin},
      {'code': codeFrench, 'name': loc.french},
      {'code': codeSpanish, 'name': loc.spanish},
    ];
  }

  // 앱 언어 코드에 해당하는 표시명 반환 (로컬라이즈)
  static String getAppLanguageDisplayName(String code, AppLocalizations loc) {
    final normalized = code.trim().toLowerCase();
    switch (normalized) {
      case 'ko':
        return loc.korean;
      case 'en':
        return loc.english;
      case 'zh-tw':
        return loc.taiwanMandarin;
      case 'zh':
      case 'zh-cn':
        return loc.chinese;
      case 'fr':
        return loc.french;
      case 'es':
        return loc.spanish;
      default:
        return loc.english;
    }
  }

  // AppLocalizations 기반 다국어 표시용 (옵셔널)
  static List<Map<String, String>> getLocalizedTranslationLanguages(
    AppLocalizations loc,
  ) {
    final base = [
      {'code': uiEnglish, 'name': loc.english},
      {'code': uiKorean, 'name': loc.korean},
      {'code': uiJapanese, 'name': loc.japanese},
      {'code': uiChinese, 'name': loc.chinese},
      {'code': uiChineseTaiwan, 'name': loc.taiwanMandarin},
      {'code': uiSpanish, 'name': loc.spanish},
      {'code': uiFrench, 'name': loc.french},
      {'code': uiGerman, 'name': loc.german},
    ];

    // 사용자 언어를 앞으로 정렬
    try {
      final user = _uiNameFromSystemLocale(
        WidgetsBinding.instance.platformDispatcher.locale,
      );
      if (user == null) return base;
      final first = base.firstWhere(
        (m) => m['code'] == user,
        orElse: () => base.first,
      );
      final sorted = <Map<String, String>>[first];
      for (final m in base) {
        if (m['code'] != user) sorted.add(m);
      }
      return sorted;
    } catch (_) {
      return base;
    }
  }

  // 유틸리티
  static Locale createLocale(String languageCode) {
    if (languageCode == codeChineseTaiwan || languageCode == 'zh-TW') {
      return const Locale('zh', 'TW');
    }
    if (languageCode == codeChineseSimplified || languageCode == 'zh-CN') {
      return const Locale('zh');
    }
    return Locale(languageCode);
  }

  static String? _uiNameFromSystemLocale(Locale locale) {
    final lc = locale.languageCode;
    final cc = locale.countryCode;
    if (lc == 'ko') return uiKorean;
    if (lc == 'en') return uiEnglish;
    if (lc == 'ja') return uiJapanese;
    if (lc == 'zh' && cc == 'TW') return uiChineseTaiwan;
    if (lc == 'zh') return uiChinese;
    if (lc == 'fr') return uiFrench;
    if (lc == 'de') return uiGerman;
    if (lc == 'es') return uiSpanish;
    return null;
  }

  static void dispose() {
    _languageController.close();
  }
}
