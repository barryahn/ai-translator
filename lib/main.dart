// 메인
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ai_translator/l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:vibration/vibration.dart';
// 서비스
import 'services/openai_service.dart';
import 'services/language_service.dart';
import 'services/theme_service.dart';
import 'services/language_detect_service.dart';
import 'services/tts_service.dart';
import 'services/translation_history_service.dart';
// 화면
import 'setting_screen.dart';
import 'terms_of_service_screen.dart';
import 'translation_history_screen.dart';
// 테마
import 'theme/app_theme.dart';

// 무료 버전에서는 일정 길이 이상 입력 시 잘라냅니다.
final int maxInputLengthInFreeVersion = 500;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await OpenAIService.initialize();
  await ThemeService.initialize();
  await LanguageService.initialize();
  await TranslationHistoryService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Locale _appLocale;
  StreamSubscription<Map<String, String>>? _langSub;

  @override
  void initState() {
    super.initState();
    _appLocale = LanguageService.createLocale(LanguageService.appLanguageCode);
    _langSub = LanguageService.languageStream.listen((event) {
      if (event.containsKey('appLanguage')) {
        setState(() {
          _appLocale = LanguageService.createLocale(
            LanguageService.appLanguageCode,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _langSub?.cancel();
    super.dispose();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeService>.value(
      value: ThemeService.instance,
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'Dive Translate',
            debugShowCheckedModeBanner: false,
            theme: themeService.themeData,
            locale: _appLocale,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LanguageService.getSupportedAppLocales(),
            home: const TranslationUIOnlyScreen(),
          );
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class TranslationUIOnlyScreen extends StatefulWidget {
  const TranslationUIOnlyScreen({super.key});

  @override
  State<TranslationUIOnlyScreen> createState() =>
      _TranslationUIOnlyScreenState();
}

class _TranslationUIOnlyScreenState extends State<TranslationUIOnlyScreen>
    with SingleTickerProviderStateMixin {
  String selectedFromLanguage = '영어';
  String selectedToLanguage = '한국어';

  double selectedToneLevel = 1.0; // 0: 친근, 1: 기본, 2: 공손, 3: 격식
  bool isTonePickerExpanded = false;
  bool isTonePanelVisible = false; // 하단바 상단 톤 패널 표시 여부

  bool isLanguageListOpen = false; // 하단바 위쪽 언어 선택 패널 표시 여부
  bool isSelectingFromLanguage = true; // true: 출발 언어 선택, false: 도착 언어 선택
  // 하단바의 실제 렌더링 높이를 측정하기 위한 키와 상태 값입니다.
  // 측정된 높이는 본문 하단 여백(bottomSpacer) 계산에 사용됩니다.
  final GlobalKey _bottomBarKey = GlobalKey();
  double _bottomBarHeight = 0.0;
  bool _hasReceivedFirstDelta = false; // 첫 델타 수신 여부
  late final AnimationController _loadingController; // 프리스트림 로딩 애니메이션

  bool _isFetching = false; // 현재 API 호출이 진행 중인지 여부
  // TTS는 TtsService에서 관리됩니다.
  StreamSubscription<bool>? _ttsSub;
  bool _isInputTextSpeaking = false;
  bool _isResultTextSpeaking = false;
  int? _inputSpeakStart;
  int? _inputSpeakEnd;
  int? _resultSpeakStart;
  int? _resultSpeakEnd;
  StreamSubscription<TtsProgress>? _ttsProgressSub;

  final List<String> languages =
      LanguageService.getUiLanguagesOrderedBySystem();

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _bottomInputFocusNode = FocusNode();
  String _translatedText = '';
  bool _isTranslating = false;
  bool _shouldRestoreBottomInputFocus = false;
  List<LanguageDetectResult> _inputLangCandidates = [];
  double _swapButtonTurns = 0.0; // 스왑 버튼 회전(1.0 = 360도)
  double _swapIconTurns = 0.0; // 아이콘 자체 360도 회전(1.0 = 360도)
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _resultSectionKey = GlobalKey();
  String _lastInputText = '';
  double _resultSectionHeight = 0.0;
  String? _fromLanguageAtLastTranslate;
  String? _toLanguageAtLastTranslate;

  void _hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _showLanguagePicker({required bool selectingFrom}) {
    setState(() {
      if (isLanguageListOpen && isSelectingFromLanguage == selectingFrom) {
        // 같은 드롭다운을 다시 누르면 닫기
        isLanguageListOpen = false;
      } else {
        // 다른 드롭다운이거나 닫혀 있으면 열기/전환
        isSelectingFromLanguage = selectingFrom;
        isLanguageListOpen = true;
        // 언어 선택 창을 열면 번역 분위기 탭은 닫기
        isTonePanelVisible = false;
      }
    });
  }

  // static const double _minFieldHeight = 200.0;
  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // 언어 감지 서비스 초기화
    LanguageDetectService.instance.initialize();

    // LanguageService의 저장값을 화면 상태에 반영
    selectedFromLanguage = LanguageService.fromLanguage;
    selectedToLanguage = LanguageService.toLanguage;

    // TTS 초기화는 TtsService에서 처리됩니다.
    _ttsSub = TtsService.instance.speakingStream.listen((speaking) {
      if (!mounted) return;
    });
    _ttsProgressSub = TtsService.instance.progressStream.listen((progress) {
      if (!mounted) return;
      setState(() {
        if (_isInputTextSpeaking) {
          _inputSpeakStart = progress.start;
          _inputSpeakEnd = progress.end;
        } else if (_isResultTextSpeaking) {
          _resultSpeakStart = progress.start;
          _resultSpeakEnd = progress.end;
        }
      });
    });
  }

  List<String> get toneLabels => [
    AppLocalizations.of(context).friendly,
    AppLocalizations.of(context).basic,
    AppLocalizations.of(context).polite,
    AppLocalizations.of(context).formal,
  ];

  String _buildToneInstruction() {
    int toneIndex = selectedToneLevel.round();

    switch (toneIndex) {
      // 친구
      case 0:
        return '친구에게 말하듯이 친근하고 편안한 말투로 번역해주세요.';
      // 공손
      case 2:
        return '공적인 자리에서 사용할 수 있도록 공손하고 예의 바른 톤으로 번역해주세요.';
      // 격식
      case 3:
        return '문서에서 사용하려고 합니다. 격식 있고 공식적인 톤으로 번역해주세요.';
      // 기본
      case 1:
      default:
        return '자연스럽게 번역해주세요.';
    }
  }

  bool _isChineseUiLanguage(String uiName) {
    return uiName == LanguageService.uiChinese ||
        uiName == LanguageService.uiChineseTaiwan;
  }

  Widget _buildPinyinWidgetIfNeeded(
    String text, {
    required bool isForInput,
    required CustomColors colors,
  }) {
    final String uiLang = isForInput
        ? (_fromLanguageAtLastTranslate ?? selectedFromLanguage)
        : (_toLanguageAtLastTranslate ?? selectedToLanguage);
    if (text.trim().isEmpty || !_isChineseUiLanguage(uiLang)) {
      return const SizedBox.shrink();
    }
    final String pinyin = PinyinHelper.getPinyin(
      text,
      separator: ' ',
      format: PinyinFormat.WITH_TONE_MARK,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SelectableText(
        pinyin,
        style: TextStyle(color: colors.textLight, fontSize: 13, height: 1.4),
      ),
    );
  }

  Widget _buildHighlightedSelectableText(
    String text, {
    required bool isForInput,
    required CustomColors colors,
    required TextStyle baseStyle,
  }) {
    final bool isSpeaking = isForInput
        ? _isInputTextSpeaking
        : _isResultTextSpeaking;
    final int? start = isForInput ? _inputSpeakStart : _resultSpeakStart;
    final int? end = isForInput ? _inputSpeakEnd : _resultSpeakEnd;
    if (!isSpeaking) {
      return SelectableText.rich(
        TextSpan(
          text: text,
          style: baseStyle.copyWith(color: colors.text),
        ),
      );
    }
    if (text.isEmpty) {
      return SelectableText.rich(
        TextSpan(
          text: text,
          style: baseStyle.copyWith(color: colors.text),
        ),
      );
    }
    // 발화 중인데 아직 진행 인덱스가 없다면 전체를 연하게 표시
    if (start == null || end == null || start < 0 || end <= start) {
      return SelectableText.rich(
        TextSpan(
          text: text,
          style: baseStyle.copyWith(color: colors.text.withValues(alpha: 0.45)),
        ),
      );
    }
    final int clampedEnd = end.clamp(0, text.length);
    final int clampedStart = start.clamp(0, clampedEnd);
    final String before = text.substring(0, clampedStart);
    final String current = text.substring(clampedStart, clampedEnd);
    final String after = text.substring(clampedEnd);
    final Color faded = colors.text.withValues(alpha: 0.45);
    return SelectableText.rich(
      TextSpan(
        style: baseStyle,
        children: [
          if (before.isNotEmpty)
            TextSpan(
              text: before,
              style: TextStyle(color: faded),
            ),
          if (current.isNotEmpty)
            TextSpan(
              text: current,
              style: TextStyle(color: colors.text),
            ),
          if (after.isNotEmpty)
            TextSpan(
              text: after,
              style: TextStyle(color: faded),
            ),
        ],
      ),
    );
  }

  Future<void> _speakText(String text, {required String uiLanguage}) async {
    await TtsService.instance.speak(text, uiLanguage: uiLanguage);
  }

  // 언어 매핑은 LanguageService에서 관리

  Future<void> _runTranslate() async {
    final text = _inputController.text.trim();
    String buffer = '';

    if (text.isEmpty) {
      Fluttertoast.showToast(msg: '번역할 텍스트를 입력하세요');
      return;
    }
    /* // 입력 언어 감지 및 콘솔 출력 (서비스 사용)
    LanguageDetectService.instance.detectRealtime(
      text: text,
      debounce: const Duration(milliseconds: 0),
      onDetected: (res) {
        final String name = LanguageService.getUiLanguageFromCode(res.code);
        print('입력 언어 감지: ' + res.code + ' (' + name + ')');
      },
      onError: (e) {
        print('입력 언어 감지 실패: ' + e.toString());
      },
    ); */

    setState(() {
      _lastInputText = text;
      _isTranslating = true;
      _isFetching = true;
      _hasReceivedFirstDelta = false;
      _translatedText = '';
      _fromLanguageAtLastTranslate = selectedFromLanguage;
      _toLanguageAtLastTranslate = selectedToLanguage;
    });

    // 스크롤: 먼저 맨 위로, 이후 번역 결과 섹션이 보이도록 이동
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
        await Future.delayed(const Duration(milliseconds: 120));
        final ctx = _resultSectionKey.currentContext;
        if (ctx != null) {
          await Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            alignment: 0.0,
          );
        }
      } catch (_) {}
    });

    try {
      final from = LanguageService.mapUiLanguageToApi(selectedFromLanguage);
      final to = LanguageService.mapUiLanguageToApi(selectedToLanguage);
      final toneInstruction = _buildToneInstruction();
      // 무료/프로 모델 선택 로직은 임시로 무료 고정
      const usingProModel = false;
      OpenAIService.translateText(
        text,
        from,
        to,
        toneInstruction,
        usingProModel,
        (delta) {
          if (!_isFetching) return;
          buffer += delta;
          if (!mounted) return;
          setState(() {
            if (!_hasReceivedFirstDelta && buffer.isNotEmpty) {
              _hasReceivedFirstDelta = true; // 프리스트림 로딩 → 스트리밍 중 전환
              // 스트리밍 시작 시 작은 진동
              Vibration.vibrate(duration: 50);
            }
            _translatedText = buffer; // 스트리밍 도중 실시간 업데이트
          });
        },
        () {
          if (!_isFetching) return;
          if (!mounted) return;
          setState(() {
            _translatedText = buffer; // 최종 결과 보장
            _isFetching = false;
            _isTranslating = false;
          });
          // 번역 기록 저장 (비동기)
          if (buffer.trim().isNotEmpty) {
            unawaited(
              TranslationHistoryService.instance.addHistory(
                fromUiLanguage:
                    _fromLanguageAtLastTranslate ?? selectedFromLanguage,
                toUiLanguage: _toLanguageAtLastTranslate ?? selectedToLanguage,
                inputText: _lastInputText,
                resultText: buffer,
              ),
            );
          }
        },
        (error) {
          if (!_isFetching) return;
          if (!mounted) return;
          Fluttertoast.showToast(msg: '번역 중 오류가 발생했습니다');
          setState(() {
            _isFetching = false;
            _isTranslating = false;
          });
        },
      );
    } catch (e) {
      Fluttertoast.showToast(msg: '번역 중 오류가 발생했습니다');
      if (mounted) {
        setState(() {
          _isFetching = false;
          _isTranslating = false;
        });
      }
    }
  }

  int _computeLineCount(String text, double maxWidth, TextStyle style) {
    if (text.isEmpty) return 1;
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);
    final double lineHeight = painter.preferredLineHeight;
    final int lines = (painter.height / lineHeight).ceil();
    return lines;
  }

  double _getDropdownFontSize(String text, {bool isSelected = false}) {
    final int length = text.length;
    if (isSelected) {
      if (length > 18) return 13.0;
      if (length > 12) return 14.0;
      if (length > 7) return 15.0;
      return 17.0;
    } else {
      if (length > 18) return 14.0;
      return 16.0;
    }
  }

  String _localizedNameFor(String code) {
    final items = LanguageService.getLocalizedTranslationLanguages(
      AppLocalizations.of(context),
    );
    final match = items.firstWhere(
      (m) => m['code'] == code,
      orElse: () => {'name': code},
    );
    return match['name'] ?? code;
  }

  // 번역 결과 텍스트 길이에 따라 폰트 크기를 부드럽게 조절합니다.
  // 짧은 텍스트는 크게(최대 22), 긴 텍스트는 작게(최소 14).
  double _getAdaptiveResultFontSize(String text) {
    if (text.isEmpty) return 15.0;
    final int length = text.runes.length;
    const double minSize = 14.0;
    const double maxSize = 28.0;
    // 60자 이하는 최대, 600자 이상은 최소로 선형 보간
    if (length <= 60) return maxSize;
    if (length >= 600) return minSize;
    final double t = (length - 60) / (600 - 60);
    return maxSize - (maxSize - minSize) * t;
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;
    // 하단바 높이 측정 및 본문 여백 계산
    // 프레임 렌더링 이후에 실제 사이즈(RenderBox)를 읽어 정확한 높이를 얻습니다.
    // 값이 의미 있게 변할 때만 setState하여 불필요한 리빌드를 방지합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _bottomBarKey.currentContext;
      if (ctx != null) {
        final renderObject = ctx.findRenderObject();
        if (renderObject is RenderBox) {
          final newHeight = renderObject.size.height;
          if ((_bottomBarHeight - newHeight).abs() > 0.5) {
            setState(() {
              _bottomBarHeight = newHeight;
            });
          }
        }
      }
      // 번역 결과 섹션 실제 높이 측정
      final rCtx = _resultSectionKey.currentContext;
      if (rCtx != null) {
        final r = rCtx.findRenderObject();
        if (r is RenderBox) {
          final h = r.size.height;
          if ((_resultSectionHeight - h).abs() > 0.5) {
            setState(() {
              _resultSectionHeight = h;
            });
          }
        }
      }
    });
    // 키보드가 올라올 때는 키보드 높이(viewInsets.bottom)만큼도 추가로 확보합니다.
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    // 항상 하단바(+키보드) 높이만큼 본문 하단 여백을 줘서 컨텐츠가 가려지지 않게 합니다.
    final double bottomSpacer = _bottomBarHeight + (keyboardInset * 0.92);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: colors.background,
          // 하단바를 본문 위에 겹치게 렌더링하여 뒤 컨텐츠가 비치도록 합니다.
          extendBody: true,
          appBar: AppBar(
            leading: Builder(
              builder: (context) => IconButton(
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 18, height: 2, color: colors.text),
                    SizedBox(height: 4),
                    Container(width: 14, height: 2, color: colors.text),
                  ],
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: Text(
              AppLocalizations.of(context).app_title,
              style: TextStyle(
                color: colors.text,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            titleSpacing: 2,
            backgroundColor: colors.background,
            iconTheme: IconThemeData(color: colors.text),
            elevation: 0,
            scrolledUnderElevation: 0.1,
            shadowColor: colors.text.withValues(alpha: 0.3),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: Icon(Icons.image_search, color: colors.text),
                  onPressed: () {
                    if (_isFetching) {
                      return;
                    }
                    Fluttertoast.showToast(
                      msg: AppLocalizations.of(context).feature_coming_soon,
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                    );
                  },
                ),
              ),
            ],
          ),
          drawer: _buildAppDrawer(context),
          onDrawerChanged: (isOpened) {
            if (isOpened) {
              // 드로어가 열릴 때 현재 하단 입력창 포커스 상태를 저장하고, 드로어 열림에 의해 포커스가 바뀌지 않도록 함
              _shouldRestoreBottomInputFocus = _bottomInputFocusNode.hasFocus;
              _hideKeyboard();
              if (isLanguageListOpen) {
                setState(() {
                  isLanguageListOpen = false;
                });
              }
              if (isTonePanelVisible) {
                setState(() {
                  isTonePanelVisible = false;
                });
              }
            } else {
              // 드로어가 닫힐 때 이전 포커스 상태를 복원
              if (_shouldRestoreBottomInputFocus) {
                FocusScope.of(context).requestFocus(_bottomInputFocusNode);
              } else {
                _hideKeyboard();
              }
            }
          },
          bottomNavigationBar: _buildBottomSearchBar(colors),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusScope.of(context).unfocus();
              if (isLanguageListOpen) {
                setState(() {
                  isLanguageListOpen = false;
                });
              }
              if (isTonePanelVisible) {
                setState(() {
                  isTonePanelVisible = false;
                });
              }
            },
            onHorizontalDragUpdate: (details) {
              // 왼쪽에서 오른쪽으로 스와이프할 때 drawer 열기
              if (details.delta.dx > 0) {
                Scaffold.of(context).openDrawer();
              }
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: <Widget>[
                    _buildTranslationArea(colors),
                    // 하단바 + 키보드 높이만큼 동적 여백을 추가합니다.
                    SizedBox(height: bottomSpacer),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_inputLangCandidates.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: bottomSpacer + 8),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildInputLangOverlay(colors),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    LanguageDetectService.instance.dispose();
    _loadingController.dispose();
    _bottomInputFocusNode.dispose();
    _scrollController.dispose();
    TtsService.instance.stop();
    _ttsSub?.cancel();
    _ttsProgressSub?.cancel();
    super.dispose();
  }

  Widget _buildAppDrawer(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Drawer(
      backgroundColor: colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8), // 왼쪽 드로어일 때 둥글게 할 모서리
          bottomRight: Radius.circular(8),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              color: colors.background,
              child: Text(
                AppLocalizations.of(context).get('menu'),
                style: TextStyle(
                  color: colors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: colors.textLight.withValues(alpha: 0.1)),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                width: 24,
                height: 24,
                child: Icon(Icons.history, color: colors.text),
              ),
              title: Text(AppLocalizations.of(context).translation_history),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TranslationHistoryScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                width: 24,
                height: 24,
                child: Icon(Icons.article, color: colors.text),
              ),
              title: Text(AppLocalizations.of(context).get('terms_of_service')),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TermsOfServiceScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                width: 24,
                height: 24,
                child: Icon(Icons.settings, color: colors.text),
              ),
              title: Text(AppLocalizations.of(context).get('settings')),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(CustomColors colors) {
    return Row(
      children: <Widget>[
        Expanded(flex: 5, child: _buildFromLanguageDropdown(colors)),
        Expanded(
          flex: 2,
          child: Center(child: _buildLanguageSwapButton(colors)),
        ),
        Expanded(flex: 5, child: _buildToLanguageDropdown(colors)),
      ],
    );
  }

  Widget _buildFromLanguageDropdown(colors) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: colors.text.withValues(alpha: 0.08),
        onTap: () => _showLanguagePicker(selectingFrom: true),
        child: Container(
          height: 40,
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _localizedNameFor(selectedFromLanguage),
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _getDropdownFontSize(
                      _localizedNameFor(selectedFromLanguage),
                      isSelected: true,
                    ),
                    height: 1.2,
                    color: colors.text,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more, size: 18, color: colors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSwapButton(CustomColors colors) {
    return AnimatedRotation(
      turns: _swapButtonTurns,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.textLight.withValues(alpha: 0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          splashColor: colors.text.withValues(alpha: 0.08),
          highlightColor: colors.text.withValues(alpha: 0.04),
          onTap: () {
            setState(() {
              final temp = selectedFromLanguage;
              selectedFromLanguage = selectedToLanguage;
              selectedToLanguage = temp;
              _swapButtonTurns += 0.5; // 180도 회전
              _swapIconTurns += 0.5; // 아이콘 360도 회전
            });
            // 서비스에도 반영
            LanguageService.swapTranslationLanguages();
          },
          child: SizedBox(
            width: 36,
            height: 28,
            child: Center(
              child: AnimatedRotation(
                turns: _swapIconTurns,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: colors.text,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToLanguageDropdown(CustomColors colors) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: colors.text.withValues(alpha: 0.08),
        onTap: () => _showLanguagePicker(selectingFrom: false),
        child: Container(
          height: 40,
          // 시각적 배경은 투명 처리하여 뒤 그라데이션이 비치도록 합니다.
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _localizedNameFor(selectedToLanguage),
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _getDropdownFontSize(
                      _localizedNameFor(selectedToLanguage),
                      isSelected: true,
                    ),
                    height: 1.2,
                    color: colors.text,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more, size: 18, color: colors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguagePickerPanel(CustomColors colors) {
    final String title = isSelectingFromLanguage
        ? AppLocalizations.of(context).select_from_language
        : AppLocalizations.of(context).select_to_language;
    final String current = isSelectingFromLanguage
        ? selectedFromLanguage
        : selectedToLanguage;
    return Container(
      decoration: BoxDecoration(
        color: colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: colors.textLight.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textLight,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => isLanguageListOpen = false),
                  child: Icon(Icons.close, size: 18, color: colors.textLight),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: languages.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 0.5,
                color: colors.textLight.withValues(alpha: 0.08),
              ),
              itemBuilder: (context, index) {
                final name = languages[index];
                final bool selected = name == current;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    splashColor: colors.text.withValues(alpha: 0.08),
                    highlightColor: colors.text.withValues(alpha: 0.04),
                    onTap: () {
                      setState(() {
                        if (isSelectingFromLanguage) {
                          if (name == selectedToLanguage) {
                            final tmp = selectedFromLanguage;
                            selectedFromLanguage = selectedToLanguage;
                            selectedToLanguage = tmp;
                          } else {
                            selectedFromLanguage = name;
                          }
                        } else {
                          if (name == selectedFromLanguage) {
                            final tmp = selectedToLanguage;
                            selectedToLanguage = selectedFromLanguage;
                            selectedFromLanguage = tmp;
                          } else {
                            selectedToLanguage = name;
                          }
                        }
                        isLanguageListOpen = false;
                      });
                      // 서비스에도 반영
                      LanguageService.setTranslationLanguages(
                        fromLanguage: selectedFromLanguage,
                        toLanguage: selectedToLanguage,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _localizedNameFor(name),
                              style: TextStyle(
                                fontSize: _getDropdownFontSize(
                                  _localizedNameFor(name),
                                ),
                                color: colors.text,
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check, size: 18, color: colors.primary),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTonePicker(CustomColors colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.textLight.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                isTonePickerExpanded = !isTonePickerExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context).translation_tone,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.text.withValues(alpha: 0.8),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isTonePanelVisible = !isTonePanelVisible;
                        if (isTonePanelVisible) {
                          isLanguageListOpen = false;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        color: colors.text.withValues(alpha: 0.8),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: colors.textLight,
                    inactiveTrackColor: colors.text.withValues(alpha: 0.12),
                    thumbColor: colors.textLight,
                    overlayColor: colors.primary.withValues(alpha: 0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                  ),
                  child: Slider(
                    value: selectedToneLevel,
                    min: 0,
                    max: 3,
                    divisions: 3,
                    onChanged: (value) {
                      setState(() {
                        selectedToneLevel = value;
                      });
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: toneLabels.asMap().entries.map((entry) {
                    int index = entry.key;
                    String label = entry.value;
                    bool isSelected = selectedToneLevel.round() == index;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          selectedToneLevel = index.toDouble();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        color: colors.background,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? colors.primary
                                : colors.textLight,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationArea(CustomColors colors) {
    final mediaQuery = MediaQuery.of(context);
    final double contentViewportHeight =
        mediaQuery.size.height -
        mediaQuery.padding.top -
        kToolbarHeight -
        _bottomBarHeight -
        10 -
        (mediaQuery.viewInsets.bottom * 0.92);
    final bool showingResultState =
        _isTranslating || _translatedText.isNotEmpty;
    return Column(
      children: [
        _buildInputSummaryField(colors),
        _buildResultField(colors),
        if (showingResultState)
          SizedBox(
            height: math.max(0, contentViewportHeight - _resultSectionHeight),
          ),
      ],
    );
  }

  Widget _buildPrestreamLoading(CustomColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: _loadingController,
          builder: (context, _) {
            final double v = _loadingController.value * 2 * math.pi;
            final List<double> phases = [0.0, 0.6, 1.2];
            List<Widget> dots = phases.map((p) {
              final double s = (math.sin(v - p) + 1) / 2; // 0..1
              final double scale = 0.6 + 0.3 * s; // 0.6..1.0
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: colors.text.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }).toList();
            return Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: dots,
            );
          },
        ),
      ],
    );
  }

  Widget _buildInputSummaryField(CustomColors colors) {
    if (_lastInputText.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  '입력한 내용',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textLight,
                  ),
                ),
                const SizedBox(width: 8),
                if (_lastInputText.isNotEmpty && !_isTranslating) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      if (_isInputTextSpeaking) {
                        await TtsService.instance.stop();
                        setState(() {
                          _isInputTextSpeaking = false;
                          _isResultTextSpeaking = false;
                          _inputSpeakStart = null;
                          _inputSpeakEnd = null;
                        });
                      } else {
                        setState(() {
                          _isInputTextSpeaking = true;
                          _isResultTextSpeaking = false;
                          _inputSpeakStart = null;
                          _inputSpeakEnd = null;
                        });

                        await _speakText(
                          _lastInputText,
                          uiLanguage:
                              _fromLanguageAtLastTranslate ??
                              selectedFromLanguage,
                        );
                        setState(() {
                          _isInputTextSpeaking = false;
                          _inputSpeakStart = null;
                          _inputSpeakEnd = null;
                        });
                      }
                    },
                    child: Icon(
                      _isInputTextSpeaking ? Icons.stop : Icons.play_arrow,
                      size: 18,
                      color: colors.textLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: _buildHighlightedSelectableText(
              _lastInputText,
              isForInput: true,
              colors: colors,
              baseStyle: TextStyle(fontSize: 15, height: 1.45),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: _buildPinyinWidgetIfNeeded(
              _lastInputText,
              isForInput: true,
              colors: colors,
            ),
          ),
          if (_lastInputText.isNotEmpty)
            Container(
              width: double.infinity,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _inputController.text = _lastInputText;
                        _inputController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _inputController.text.length),
                        );
                        isLanguageListOpen = false;
                        isTonePanelVisible = false;
                        selectedFromLanguage =
                            _fromLanguageAtLastTranslate ??
                            selectedFromLanguage;
                        selectedToLanguage =
                            _toLanguageAtLastTranslate ?? selectedToLanguage;
                      });
                      FocusScope.of(
                        context,
                      ).requestFocus(_bottomInputFocusNode);
                      // 편집 버튼으로 텍스트를 넣은 경우:
                      // 1) 기존 제안 숨김 → 2) 즉시 언어 감지 → 3) 결과 수신 시 오버레이 표시
                      setState(() {
                        _inputLangCandidates = [];
                      });
                      // 언어 감지 즉시 실행 (디바운스 0ms)
                      LanguageDetectService.instance.detectRealtimeAll(
                        text: _inputController.text,
                        debounce: const Duration(milliseconds: 0),
                        onDetected: (list) {
                          if (!mounted) return;
                          setState(() {
                            _inputLangCandidates = list;
                          });
                        },
                        onError: (e) {},
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(shape: BoxShape.circle),
                      child: Icon(
                        Icons.edit,
                        size: 18,
                        color: colors.text.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _lastInputText),
                      );
                      Fluttertoast.showToast(
                        msg: AppLocalizations.of(context).input_text_copied,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(shape: BoxShape.circle),
                      child: Icon(
                        Icons.copy,
                        size: 18,
                        color: colors.text.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputLangOverlay(CustomColors colors) {
    String? suggestedFromUi;
    for (final r in _inputLangCandidates) {
      if (r.probability < 0.54) continue;
      final String uiName = LanguageService.getUiLanguageFromCode(r.code);
      if (languages.contains(uiName)) {
        suggestedFromUi = uiName;
        break;
      }
    }

    if (_inputController.text.isEmpty ||
        suggestedFromUi == null ||
        suggestedFromUi == selectedFromLanguage) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: colors.text.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.textLight.withValues(alpha: 0.12)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            splashColor: colors.text.withValues(alpha: 0.08),
            highlightColor: colors.text.withValues(alpha: 0.04),
            onTap: () {
              if (suggestedFromUi == null) return;
              setState(() {
                if (suggestedFromUi == selectedToLanguage) {
                  final tmp = selectedFromLanguage;
                  selectedFromLanguage = selectedToLanguage;
                  selectedToLanguage = tmp;
                } else {
                  selectedFromLanguage = suggestedFromUi!;
                }
                LanguageService.setTranslationLanguages(
                  fromLanguage: selectedFromLanguage,
                  toLanguage: selectedToLanguage,
                );
                _inputLangCandidates = [];
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 4,
                    top: 10,
                    bottom: 10,
                  ),
                  child: Icon(
                    Icons.language,
                    size: 16,
                    color: colors.textLight,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  child: Text(
                    '출발 언어를 ${suggestedFromUi}로 변경',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.text,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _inputLangCandidates = [];
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.only(
                      right: 6,
                      top: 6,
                      bottom: 6,
                      left: 6,
                    ),
                    child: Icon(Icons.close, size: 16, color: colors.textLight),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 입력 컨테이너는 하단 검색바로 대체됨
  Widget _buildBottomSearchBar(CustomColors colors) {
    // 키보드가 올라오면 하단 패딩을 늘려 바가 키보드 위에 위치하게 합니다.
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      // 하단바 배경 그라데이션: 아래쪽은 불투명, 위로 갈수록 투명해집니다.
      // 하단바 가장 밑 비어 있는 공간을 채우기 위해 추가
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(0.0, 0.0),
          end: Alignment(0.0, -0.1),
          colors: [colors.background, colors.background.withValues(alpha: 0.0)],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Container(
            // 본 컨테이너의 실제 높이를 측정하기 위한 키입니다.
            key: _bottomBarKey,
            decoration: BoxDecoration(
              // 하단바 배경 추가 그라데이션: 아래쪽은 불투명, 위로 갈수록 투명해집니다.
              gradient: LinearGradient(
                begin: Alignment(0.0, -0.68),
                end: Alignment.topCenter,
                colors: [
                  colors.background,
                  colors.background.withValues(alpha: 0.0),
                ],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 하단바 최상단에 톤 선택 배치 (버튼으로 토글 표시)
                if (isTonePanelVisible) ...[
                  _buildTonePicker(colors),
                  const SizedBox(height: 4),
                ],
                if (isLanguageListOpen) ...[
                  _buildLanguagePickerPanel(colors),
                  const SizedBox(height: 10),
                ],
                // 언어 선택자 (하단 바 상단에 배치)
                Container(child: _buildLanguageSelector(colors)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 이미지 스캔 버튼
                    Column(
                      children: [
                        Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            splashColor: colors.text.withValues(alpha: 0.08),
                            onTap: () {
                              setState(() {
                                // 언어 선택 패널은 닫고 톤 패널 토글
                                isLanguageListOpen = false;
                                isTonePanelVisible = !isTonePanelVisible;
                                // 처음 열 때 즉시 슬라이더 보이도록 확장 상태로
                                if (isTonePanelVisible) {
                                  // 톤 패널 열리면 언어 패널 닫힘 유지
                                  isLanguageListOpen = false;
                                  isTonePickerExpanded = true;
                                }
                              });
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment(0, 0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tune,
                                    color: colors.text,
                                    size: 20,
                                  ),
                                  Container(
                                    height: 14,
                                    alignment: Alignment.bottomCenter,
                                    child: Text(
                                      toneLabels[selectedToneLevel.round()],
                                      style: TextStyle(
                                        fontSize:
                                            toneLabels[selectedToneLevel
                                                        .round()]
                                                    .length >
                                                6
                                            ? 8
                                            : 11,
                                        fontWeight: FontWeight.w800,
                                        color: colors.text.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // 중앙 입력 영역 (투명 배경 + 라운드 보더)
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          splashColor: colors.text.withValues(alpha: 0.06),
                          highlightColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          onTap: () {
                            FocusScope.of(
                              context,
                            ).requestFocus(_bottomInputFocusNode);
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            decoration: BoxDecoration(
                              color: colors.textLight.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 8,
                              top: 8,
                              bottom: 8,
                            ),
                            alignment: Alignment.centerLeft,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final TextStyle textStyle = TextStyle(
                                  color: colors.text,
                                  fontSize: 15,
                                );
                                final int lineCount = _computeLineCount(
                                  _inputController.text,
                                  constraints.maxWidth,
                                  textStyle,
                                );
                                final bool showExpand = lineCount > 4;
                                return Stack(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Container(
                                            constraints: const BoxConstraints(
                                              minHeight: 32,
                                            ),
                                            alignment: Alignment.center,
                                            child: TextField(
                                              controller: _inputController,
                                              focusNode: _bottomInputFocusNode,
                                              style: textStyle,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                border: InputBorder.none,
                                                hintText: AppLocalizations.of(
                                                  context,
                                                ).search_or_sentence_hint,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              keyboardType:
                                                  TextInputType.multiline,
                                              textInputAction:
                                                  TextInputAction.newline,
                                              minLines: 1,
                                              maxLines: 4,
                                              onChanged: (value) {
                                                setState(() {});
                                                LanguageDetectService.instance
                                                    .detectRealtimeAll(
                                                      text: value,
                                                      onDetected: (list) {
                                                        setState(() {
                                                          _inputLangCandidates =
                                                              list;
                                                        });
                                                        // ### HEAD 콘솔 출력 위한 부분 ###
                                                        print(
                                                          '실시간 입력 언어 후보2: ${list.toList().map((r) => '${r.code} (${LanguageService.getUiLanguageFromCode(r.code)}) ${r.probability}').join(', ')}',
                                                        );
                                                        // ### END 콘솔 출력 위한 부분 ###
                                                      },
                                                      onError: (e) {},
                                                    );
                                              },
                                            ),
                                          ),
                                        ),

                                        // 입력 텍스트가 없을 때
                                        if (_inputController.text.isEmpty) ...[
                                          const SizedBox(width: 8),

                                          // 음성 입력 버튼
                                          Material(
                                            color: Colors.transparent,
                                            shape: const CircleBorder(),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              customBorder:
                                                  const CircleBorder(),
                                              splashColor: colors.text
                                                  .withValues(alpha: 0.08),
                                              onTap: () {
                                                if (_isFetching) {
                                                  // 스트리밍 중지
                                                  OpenAIService.cancelStreaming();
                                                  setState(() {
                                                    _isFetching = false;
                                                    _isTranslating = false;
                                                  });
                                                  return;
                                                }
                                                Fluttertoast.showToast(
                                                  msg: AppLocalizations.of(
                                                    context,
                                                  ).feature_coming_soon,
                                                  toastLength:
                                                      Toast.LENGTH_SHORT,
                                                  gravity: ToastGravity.BOTTOM,
                                                );
                                              },
                                              child: SizedBox(
                                                width: 32,
                                                height: 32,
                                                child: Icon(
                                                  _isFetching
                                                      ? Icons.stop
                                                      : Icons.mic_none_outlined,
                                                  color: _isFetching
                                                      ? colors.text
                                                      : colors.text.withValues(
                                                          alpha: 0.5,
                                                        ),
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],

                                        // 입력 텍스트가 있을 때
                                        if (_inputController
                                            .text
                                            .isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Material(
                                            color: Colors.transparent,
                                            shape: const CircleBorder(),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              customBorder:
                                                  const CircleBorder(),
                                              splashColor: colors.text
                                                  .withValues(alpha: 0.08),
                                              onTap: _isTranslating
                                                  ? null
                                                  : () async {
                                                      setState(() {
                                                        isLanguageListOpen =
                                                            false;
                                                        isTonePanelVisible =
                                                            false;
                                                      });
                                                      _hideKeyboard();
                                                      await _runTranslate();
                                                      if (mounted) {
                                                        setState(() {
                                                          _inputController
                                                              .clear();
                                                        });
                                                      }
                                                    },
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: _isTranslating
                                                      ? colors.textLight
                                                            .withValues(
                                                              alpha: 0.4,
                                                            )
                                                      : colors.text,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.arrow_upward,
                                                  color: colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (showExpand)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          onTap: () async {
                                            final result =
                                                await Navigator.of(
                                                  context,
                                                ).push<String>(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const _InputFullScreenEditor(),
                                                    settings: RouteSettings(
                                                      arguments:
                                                          _inputController.text,
                                                    ),
                                                  ),
                                                );
                                            if (result != null) {
                                              setState(() {
                                                _inputController.text = result;
                                              });
                                            }
                                          },
                                          child: SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: Icon(
                                              Icons.open_in_full,
                                              color: colors.text.withValues(
                                                alpha: 0.5,
                                              ),
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // 실시간 입력 언어 후보는 오버레이로 표시되므로, 하단바에서는 제거
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultField(CustomColors colors) {
    return Stack(
      children: [
        Container(
          key: _resultSectionKey,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.only(
                  left: 4,
                  right: 4,
                  top: _translatedText.isNotEmpty || _isTranslating ? 20 : 0,
                  bottom: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).translation_result,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textLight,
                      ),
                    ),
                    if (_translatedText.isNotEmpty && !_isTranslating) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          if (_isResultTextSpeaking) {
                            await TtsService.instance.stop();
                            setState(() {
                              _isResultTextSpeaking = false;
                              _isInputTextSpeaking = false;
                              _resultSpeakStart = null;
                              _resultSpeakEnd = null;
                            });
                          } else {
                            setState(() {
                              _isResultTextSpeaking = true;
                              _isInputTextSpeaking = false;
                              _resultSpeakStart = null;
                              _resultSpeakEnd = null;
                            });
                            await _speakText(
                              _translatedText,
                              uiLanguage:
                                  _toLanguageAtLastTranslate ??
                                  selectedToLanguage,
                            );
                            setState(() {
                              _isResultTextSpeaking = false;
                              _resultSpeakStart = null;
                              _resultSpeakEnd = null;
                            });
                          }
                        },
                        child: Icon(
                          _isResultTextSpeaking ? Icons.stop : Icons.play_arrow,
                          size: 18,
                          color: colors.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 페이지 전체가 이미 SingleChildScrollView이므로 내부 스크롤은 제거
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4), // 하단 버튼 공간 확보
                child:
                    (_isTranslating && _isFetching && !_hasReceivedFirstDelta)
                    ? _buildPrestreamLoading(colors)
                    : (_translatedText.isEmpty
                          ? SelectableText(
                              AppLocalizations.of(
                                context,
                              ).translation_result_hint,
                              style: TextStyle(
                                color: colors.textLight,
                                fontSize: _getAdaptiveResultFontSize(
                                  _translatedText,
                                ),
                                height: 1.4,
                              ),
                            )
                          : _buildHighlightedSelectableText(
                              _translatedText,
                              isForInput: false,
                              colors: colors,
                              baseStyle: TextStyle(
                                fontSize: _getAdaptiveResultFontSize(
                                  _translatedText,
                                ),
                                height: 1.45,
                              ),
                            )),
              ),
              if (_translatedText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                  child: _buildPinyinWidgetIfNeeded(
                    _translatedText,
                    isForInput: false,
                    colors: colors,
                  ),
                ),
              if (_translatedText.isNotEmpty)
                Container(
                  width: double.infinity,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _inputController.text = _translatedText;
                            _inputController.selection =
                                TextSelection.fromPosition(
                                  TextPosition(
                                    offset: _inputController.text.length,
                                  ),
                                );
                            isLanguageListOpen = false;
                            isTonePanelVisible = false;
                            selectedFromLanguage =
                                _toLanguageAtLastTranslate ??
                                selectedFromLanguage;
                            selectedToLanguage =
                                _fromLanguageAtLastTranslate ??
                                selectedToLanguage;
                          });
                          FocusScope.of(
                            context,
                          ).requestFocus(_bottomInputFocusNode);
                          // 편집 버튼으로 텍스트를 넣은 경우:
                          // 1) 기존 제안 숨김 → 2) 즉시 언어 감지 → 3) 결과 수신 시 오버레이 표시
                          setState(() {
                            _inputLangCandidates = [];
                          });
                          // 언어 감지 즉시 실행 (디바운스 0ms)
                          LanguageDetectService.instance.detectRealtimeAll(
                            text: _inputController.text,
                            debounce: const Duration(milliseconds: 0),
                            onDetected: (list) {
                              if (!mounted) return;
                              setState(() {
                                _inputLangCandidates = list;
                              });
                            },
                            onError: (e) {},
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(shape: BoxShape.circle),
                          child: Icon(
                            Icons.edit,
                            size: 18,
                            color: colors.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _translatedText),
                          );
                          Fluttertoast.showToast(
                            msg: AppLocalizations.of(
                              context,
                            ).translation_result_copied,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(shape: BoxShape.circle),
                          child: Icon(
                            Icons.copy,
                            size: 18,
                            color: colors.text.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InputFullScreenEditor extends StatefulWidget {
  const _InputFullScreenEditor();

  @override
  State<_InputFullScreenEditor> createState() => _InputFullScreenEditorState();
}

class _InputFullScreenEditorState extends State<_InputFullScreenEditor> {
  late final TextEditingController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      // 라우트 인자로 넘어온 초기 텍스트를 에디터 컨트롤러에 세팅합니다.
      final args = ModalRoute.of(context)?.settings.arguments;
      final initialText = args is String ? args : '';
      _controller.text = initialText;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  Future<bool> _handleWillPop() async {
    // 뒤로가기 시 현재 작성한 텍스트를 호출자에게 반환합니다.
    // 무료 버전에서는 일정 길이 이상 입력 시 잘라냅니다.
    final text = _controller.text;
    final limited = text.length > maxInputLengthInFreeVersion
        ? text.substring(0, maxInputLengthInFreeVersion)
        : text;
    Navigator.of(context).pop<String>(limited);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;
    return PopScope(
      canPop: false, // 직접 제어하므로 false
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return; // 이미 pop 된 경우 추가 처리 X

        final shouldPop = await _handleWillPop();
        if (shouldPop) {
          Navigator.of(context).pop(result);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(title: Text(AppLocalizations.of(context).input_text)),
        body: Stack(
          children: [
            // 전체 화면 텍스트 에디터 영역
            Container(
              height: MediaQuery.of(context).size.height,
              padding: EdgeInsets.only(bottom: 64),
              color: colors.white,
              child: SingleChildScrollView(
                child: TextField(
                  style: TextStyle(color: colors.text, fontSize: 15),
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  maxLines: null,

                  // 무료 버전에서는 일정 길이 이상 입력 시 잘라냅니다.
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      maxInputLengthInFreeVersion,
                    ),
                  ],
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: AppLocalizations.of(context).input_text_hint,
                    filled: true,
                    fillColor: colors.white,
                    contentPadding: const EdgeInsets.only(
                      top: 20,
                      left: 20,
                      right: 20,
                      bottom: 20,
                    ),
                  ),
                ),
              ),
            ),
            // 하단바 영역: search_result_screen.dart의 초기 하단바 디자인을 참고
            // 키보드가 올라오면 자동으로 키보드 위로 배치되도록 Stack + Positioned 사용
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: false,
                child: BottomAppBar(
                  color: colors.background,
                  height: 64,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          "${_controller.text.length} / $maxInputLengthInFreeVersion",
                          style: TextStyle(
                            color:
                                _controller.text.length >=
                                    maxInputLengthInFreeVersion
                                ? colors.error
                                : colors.text,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // 체크 버튼: 원형 버튼 스타일, 누르면 작성한 텍스트를 반환하고 닫습니다.
                      ElevatedButton(
                        onPressed: () {
                          // 무료 버전에서는 일정 길이 이상 입력 시 잘라냅니다.
                          final text = _controller.text;
                          final limited =
                              text.length > maxInputLengthInFreeVersion
                              ? text.substring(0, maxInputLengthInFreeVersion)
                              : text;
                          Navigator.of(context).pop<String>(limited);
                        },
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(2),
                          backgroundColor: colors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(
                            Icons.check,
                            color: colors.text,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
