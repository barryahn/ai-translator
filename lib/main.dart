import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ai_translator/l10n/app_localizations.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

// 무료 버전에서는 일정 길이 이상 입력 시 잘라냅니다.
final int maxInputLengthInFreeVersion = 500;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ko'),
              Locale('en'),
              Locale('zh'),
              Locale('fr'),
              Locale('es'),
              Locale.fromSubtags(languageCode: 'zh', countryCode: 'TW'),
            ],
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

class _TranslationUIOnlyScreenState extends State<TranslationUIOnlyScreen> {
  String selectedFromLanguage = '영어';
  String selectedToLanguage = '한국어';
  double selectedToneLevel = 1.0; // 0: 친근, 1: 기본, 2: 공손, 3: 격식
  bool isTonePickerExpanded = false;

  final List<String> languages = <String>[
    '한국어',
    '영어',
    '일본어',
    '중국어',
    '대만 중국어',
    '프랑스어',
    '독일어',
    '스페인어',
  ];

  final TextEditingController _inputController = TextEditingController();
  String _translatedText = '';

  static const double _minFieldHeight = 200.0;
  double _resultFieldHeight = _minFieldHeight;

  List<String> get toneLabels => ['친근', '기본', '공손', '격식'];

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

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '번역',
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
      bottomNavigationBar: _buildBottomSearchBar(colors),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              _buildTonePicker(colors),
              const SizedBox(height: 10),
              _buildTranslationArea(colors),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
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
                '메뉴',
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
              title: const Text('검색 기록'),
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
              title: const Text('이용약관'),
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
              title: const Text('설정'),
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
    return SizedBox(
      width: double.infinity,
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          hint: Text(
            'Select Item',
            style: TextStyle(fontSize: 14, color: colors.textLight),
          ),
          items: languages
              .map(
                (String name) => DropdownMenuItem<String>(
                  value: name,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: _getDropdownFontSize(name),
                            color: colors.text,
                            height: 1.1,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (name == selectedFromLanguage)
                        Icon(Icons.check, size: 16, color: colors.primary),
                    ],
                  ),
                ),
              )
              .toList(),
          selectedItemBuilder: (context) {
            return languages
                .map(
                  (name) => Center(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _getDropdownFontSize(name, isSelected: true),
                        color: colors.text,
                        height: 1.1,
                      ),
                    ),
                  ),
                )
                .toList();
          },
          iconStyleData: IconStyleData(
            icon: SizedBox(
              width: 14,
              child: Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: colors.textLight,
              ),
            ),
            openMenuIcon: SizedBox(
              width: 14,
              child: Icon(
                Icons.arrow_drop_up,
                size: 18,
                color: colors.textLight,
              ),
            ),
            iconSize: 18,
          ),
          value: selectedFromLanguage,
          onChanged: (String? newValue) {
            if (newValue == null) return;
            setState(() {
              if (newValue == selectedToLanguage) {
                final tmp = selectedFromLanguage;
                selectedFromLanguage = selectedToLanguage;
                selectedToLanguage = tmp;
              } else {
                selectedFromLanguage = newValue;
              }
            });
          },
          buttonStyleData: ButtonStyleData(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            height: 40,
          ),
          menuItemStyleData: const MenuItemStyleData(height: 46),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
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
    return SizedBox(
      width: double.infinity,
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          hint: Text(
            'Select Item',
            style: TextStyle(fontSize: 14, color: colors.textLight),
          ),
          items: languages
              .map(
                (String name) => DropdownMenuItem<String>(
                  value: name,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: _getDropdownFontSize(name),
                            color: colors.text,
                            height: 1.1,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (name == selectedToLanguage)
                        Icon(Icons.check, size: 16, color: colors.primary),
                    ],
                  ),
                ),
              )
              .toList(),
          selectedItemBuilder: (context) {
            return languages
                .map(
                  (name) => Center(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _getDropdownFontSize(name, isSelected: true),
                        color: colors.text,
                        height: 1.1,
                      ),
                    ),
                  ),
                )
                .toList();
          },
          iconStyleData: IconStyleData(
            icon: SizedBox(
              width: 14,
              child: Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: colors.textLight,
              ),
            ),
            openMenuIcon: SizedBox(
              width: 14,
              child: Icon(
                Icons.arrow_drop_up,
                size: 18,
                color: colors.textLight,
              ),
            ),
            iconSize: 18,
          ),
          value: selectedToLanguage,
          onChanged: (String? newValue) {
            if (newValue == null) return;
            setState(() {
              if (newValue == selectedFromLanguage) {
                final tmp = selectedToLanguage;
                selectedToLanguage = selectedFromLanguage;
                selectedFromLanguage = tmp;
              } else {
                selectedToLanguage = newValue;
              }
            });
          },
          buttonStyleData: ButtonStyleData(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            height: 40,
          ),
          menuItemStyleData: const MenuItemStyleData(height: 46),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTonePicker(CustomColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                left: 20,
                right: 20,
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
                      overlayColor: colors.primary.withOpacity(0.2),
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
    return Column(
      children: [
        // 입력 컨테이너는 하단 검색바로 대체됨
        _buildResultField(colors),
      ],
    );
  }

  Widget _buildBottomSearchBar(CustomColors colors) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 언어 선택자 (하단 바 상단에 배치)
            Container(child: _buildLanguageSelector(colors)),
            const SizedBox(height: 10),
            Row(
              children: [
                // 이미지 스캔 버튼
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Fluttertoast.showToast(
                      msg: '이미지 스캔은 준비 중입니다',
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(Icons.document_scanner, color: colors.text),
                  ),
                ),
                const SizedBox(width: 10),
                // 중앙 입력 영역 (투명 배경 + 라운드 보더)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(32),
                    onTap: () async {
                      final result = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => const _InputFullScreenEditor(),
                          settings: RouteSettings(
                            arguments: _inputController.text,
                          ),
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          _inputController.text = result;
                        });
                      }
                    },
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: colors.textLight.withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _inputController.text.isEmpty
                            ? '검색어나 문장을 입력하세요'
                            : _inputController.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.text, fontSize: 15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                // 마이크 버튼
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Fluttertoast.showToast(
                      msg: '음성 입력은 준비 중입니다',
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(Icons.mic, color: colors.text),
                  ),
                ),
                const SizedBox(width: 2),
                // 검색 버튼
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () async {
                    final result = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => const _InputFullScreenEditor(),
                        settings: RouteSettings(
                          arguments: _inputController.text,
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _inputController.text = result;
                      });
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    child: Icon(Icons.search, color: colors.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultField(CustomColors colors) {
    return Container(
      height: _resultFieldHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.translate,
                      color: _translatedText.isEmpty
                          ? colors.textLight
                          : colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '번역 결과',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _translatedText.isEmpty
                            ? colors.textLight
                            : colors.text,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (_translatedText.isNotEmpty
                              ? Colors.red.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.clear,
                          size: 16,
                          color: (_translatedText.isNotEmpty
                              ? Colors.red
                              : Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (_translatedText.isNotEmpty
                              ? colors.primary.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.copy,
                          size: 16,
                          color: (_translatedText.isNotEmpty
                              ? colors.text
                              : Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      _translatedText.isEmpty
                          ? '번역 결과가 여기에 표시됩니다'
                          : _translatedText,
                      style: TextStyle(
                        color: _translatedText.isEmpty
                            ? colors.textLight
                            : colors.text,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
      appBar: AppBar(title: const Text('검색 기록')),
      body: const SizedBox.shrink(),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이용약관')),
      body: const SizedBox.shrink(),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: const SizedBox.shrink(),
    );
  }
}
