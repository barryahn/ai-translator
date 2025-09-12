import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ai_translator/l10n/app_localizations.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/openai_service.dart';
import 'services/language_service.dart';
import 'dart:math' as math;
import 'setting_screen.dart';
import 'terms_of_service_screen.dart';

// 무료 버전에서는 일정 길이 이상 입력 시 잘라냅니다.
final int maxInputLengthInFreeVersion = 500;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await OpenAIService.initialize();
  await ThemeService.initialize();
  await LanguageService.initialize();
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
            title: 'AI Translator',
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
  bool isLanguageListOpen = false; // 하단바 위쪽 언어 선택 패널 표시 여부
  bool isSelectingFromLanguage = true; // true: 출발 언어 선택, false: 도착 언어 선택
  // 하단바의 실제 렌더링 높이를 측정하기 위한 키와 상태 값입니다.
  // 측정된 높이는 본문 하단 여백(bottomSpacer) 계산에 사용됩니다.
  final GlobalKey _bottomBarKey = GlobalKey();
  double _bottomBarHeight = 0.0;
  bool _hasReceivedFirstDelta = false; // 첫 델타 수신 여부
  late final AnimationController _loadingController; // 프리스트림 로딩 애니메이션

  bool _isFetching = false; // 현재 API 호출이 진행 중인지 여부

  final List<String> languages =
      LanguageService.getUiLanguagesOrderedBySystem();

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _bottomInputFocusNode = FocusNode();
  String _translatedText = '';
  bool _isTranslating = false;
  bool _shouldRestoreBottomInputFocus = false;

  void _hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _showLanguagePicker({required bool selectingFrom}) {
    setState(() {
      isSelectingFromLanguage = selectingFrom;
      isLanguageListOpen = true;
    });
    _hideKeyboard();
  }

  // static const double _minFieldHeight = 200.0;
  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // LanguageService의 저장값을 화면 상태에 반영
    selectedFromLanguage = LanguageService.fromLanguage;
    selectedToLanguage = LanguageService.toLanguage;
  }

  List<String> get toneLabels => ['친근', '기본', '공손', '격식'];

  String _buildToneInstruction() {
    final tone = toneLabels[selectedToneLevel.round()];
    switch (tone) {
      case '친근':
        return '톤: 친근하고 캐주얼하게, 구어체 사용.';
      case '공손':
        return '톤: 공손하고 정중하게, 존댓말 사용.';
      case '격식':
        return '톤: 매우 격식 있고 전문적인 문체로.';
      case '기본':
      default:
        return '톤: 중립적이고 자연스러운 문체로.';
    }
  }

  // 언어 매핑은 LanguageService에서 관리

  Future<void> _runTranslate() async {
    final text = _inputController.text.trim();
    String buffer = '';

    if (text.isEmpty) {
      Fluttertoast.showToast(msg: '번역할 텍스트를 입력하세요');
      return;
    }
    setState(() {
      _isTranslating = true;
      _isFetching = true;
      _hasReceivedFirstDelta = false;
      _translatedText = '';
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
      if (length > 18) return 14.0;
      if (length > 12) return 14.0;
      if (length > 5) return 15.0;
      return 18.0;
    } else {
      if (length > 18) return 12.0;
      if (length > 12) return 14.0;
      if (length > 5) return 15.0;
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
    });
    // 키보드가 올라올 때는 키보드 높이(viewInsets.bottom)만큼도 추가로 확보합니다.
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    // 항상 하단바(+키보드) 높이만큼 본문 하단 여백을 줘서 컨텐츠가 가려지지 않게 합니다.
    final double bottomSpacer = _bottomBarHeight + keyboardInset;

    return Scaffold(
      backgroundColor: colors.background,
      // 하단바를 본문 위에 겹치게 렌더링하여 뒤 컨텐츠가 비치도록 합니다.
      extendBody: true,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translation,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: colors.background,
        iconTheme: IconThemeData(color: colors.text),
        elevation: 0,
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
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                _buildTonePicker(colors),
                const SizedBox(height: 20),
                _buildTranslationArea(colors),
                // 하단바 + 키보드 높이만큼 동적 여백을 추가합니다.
                SizedBox(height: bottomSpacer),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _bottomInputFocusNode.dispose();
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
              title: Text(AppLocalizations.of(context).search_history),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SearchHistoryScreen(),
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
    return GestureDetector(
      // 투명 배경에서도 터치 이벤트를 받을 수 있게 설정합니다.
      behavior: HitTestBehavior.translucent,
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
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _getDropdownFontSize(
                    _localizedNameFor(selectedFromLanguage),
                    isSelected: true,
                  ),
                  color: colors.text,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more, size: 18, color: colors.textLight),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSwapButton(CustomColors colors) {
    return GestureDetector(
      onTap: () {
        setState(() {
          final temp = selectedFromLanguage;
          selectedFromLanguage = selectedToLanguage;
          selectedToLanguage = temp;
        });
        // 서비스에도 반영
        LanguageService.swapTranslationLanguages();
      },
      child: Container(
        width: 36,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: colors.background,
          shape: BoxShape.rectangle,
          border: Border.all(color: colors.textLight.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Icon(Icons.arrow_forward_ios, color: colors.text, size: 16),
        ),
      ),
    );
  }

  Widget _buildToLanguageDropdown(CustomColors colors) {
    return GestureDetector(
      // 투명 배경에서도 터치 이벤트를 받을 수 있게 설정합니다.
      behavior: HitTestBehavior.translucent,
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
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _getDropdownFontSize(
                    _localizedNameFor(selectedToLanguage),
                    isSelected: true,
                  ),
                  color: colors.text,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more, size: 18, color: colors.textLight),
          ],
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
                return InkWell(
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
        color: colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
                top: 14,
                bottom: 14,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune, color: colors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '번역 톤',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                      if (!isTonePickerExpanded) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                toneLabels[selectedToneLevel.round()],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textLight,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Container(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.check_circle,
                                  color: colors.textLight,
                                  size: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        isTonePickerExpanded = !isTonePickerExpanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isTonePickerExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: colors.text,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isTonePickerExpanded)
            Container(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: colors.textLight,
                      inactiveTrackColor: colors.background,
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
                  const SizedBox(height: 12),
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
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.primary
                                    : colors.textLight,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
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
                          ],
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
    return Column(children: [_buildResultField(colors)]);
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
                        InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            if (_isFetching) {
                              return;
                            }
                            Fluttertoast.showToast(
                              msg: AppLocalizations.of(
                                context,
                              ).feature_coming_soon,
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                            );
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.document_scanner,
                              color: _isFetching
                                  ? colors.text.withValues(alpha: 0.5)
                                  : colors.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                    const SizedBox(width: 10),
                    // 중앙 입력 영역 (투명 배경 + 라운드 보더)
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        // Disable InkWell visual effects to prevent color overlap with inner container
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
                                    crossAxisAlignment: CrossAxisAlignment.end,
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
                                            onChanged: (_) => setState(() {}),
                                          ),
                                        ),
                                      ),

                                      // 입력 텍스트가 없을 때
                                      if (_inputController.text.isEmpty) ...[
                                        const SizedBox(width: 8),

                                        // 음성 입력 버튼
                                        InkWell(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
                                              toastLength: Toast.LENGTH_SHORT,
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
                                      ],

                                      // 입력 텍스트가 있을 때
                                      if (_inputController.text.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          onTap: _isTranslating
                                              ? null
                                              : () async {
                                                  _hideKeyboard();
                                                  await _runTranslate();
                                                  if (mounted) {
                                                    setState(() {
                                                      _inputController.clear();
                                                    });
                                                  }
                                                },
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: _isTranslating
                                                  ? colors.textLight.withValues(
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
                                      ],
                                    ],
                                  ),
                                  if (showExpand)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
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
                  ],
                ),
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
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context).translation_result,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              // 페이지 전체가 이미 SingleChildScrollView이므로 내부 스크롤은 제거
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 60), // 하단 버튼 공간 확보
                child:
                    (_isTranslating && _isFetching && !_hasReceivedFirstDelta)
                    ? _buildPrestreamLoading(colors)
                    : SelectableText(
                        _translatedText.isEmpty
                            ? AppLocalizations.of(
                                context,
                              ).translation_result_hint
                            //? 'My English teacher wanted to flunk me in junior high (Shh) Thanks a lot, next semester I\'ll be 35 I smacked him in his face with an eraser, chased him with a stapler And stapled his nuts to a stack of paper (Ow) Walked in the strip club, had my jacket zipped up Flashed the bartender, then stuck my dick in the tip cup Extraterrestrial, running over pedestrians in a spaceship While they\'re screaming at me, "Let\'s just be friends" 99 percent of my life, I was lied to I just found out my mom does more dope than I do (Damn) I told her I\'d grow up to be a famous rapper Make a record about doin\' drugs and name it after her (Oh, thank you) You know you blew up when the women rush your stands And try to touch your hands like some screamin\' Usher fans (Ahh, ahh, ahh) This guy at White Castle asked for my autograph (Dude, can I get your autograph?) So I signed it, Dear Dave, thanks for the support, asshole My English teacher wanted to flunk me in junior high (Shh) Thanks a lot, next semester I\'ll be 35 I smacked him in his face with an eraser, chased him with a stapler And stapled his nuts to a stack of paper (Ow) Walked in the strip club, had my jacket zipped up Flashed the bartender, then stuck my dick in the tip cup Extraterrestrial, running over pedestrians in a spaceship While they\'re screaming at me.'
                            : _translatedText,
                        style: TextStyle(
                          color: _translatedText.isEmpty
                              ? colors.textLight
                              : colors.text,
                          fontSize: _getAdaptiveResultFontSize(_translatedText),
                          height: 1.4,
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (_translatedText.isNotEmpty)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: _translatedText));
                Fluttertoast.showToast(
                  msg: AppLocalizations.of(context).translation_result_copied,
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

class SearchHistoryScreen extends StatelessWidget {
  const SearchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).search_history)),
      body: const SizedBox.shrink(),
    );
  }
}
