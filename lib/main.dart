import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lpinyin/lpinyin.dart';
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
  double _inputFieldHeight = _minFieldHeight;
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
          style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.background,
        iconTheme: IconThemeData(color: colors.text),
        elevation: 0,
      ),
      drawer: _buildAppDrawer(context),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              _buildLanguageSelector(colors),
              const SizedBox(height: 20),
              _buildTonePicker(colors),
              const SizedBox(height: 10),
              _buildTranslationArea(colors),
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
      child: SafeArea(
        child: Container(
          color: colors.background,
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
              Divider(
                height: 1,
                color: colors.textLight.withValues(alpha: 0.1),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('검색 기록'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SearchHistoryScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.article),
                title: const Text('이용약관'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TermsOfServiceScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('설정'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
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
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.primary)),
            ),
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
          color: colors.primary,
          shape: BoxShape.rectangle,
        ),
        child: Center(
          child: Icon(Icons.arrow_forward_ios, color: colors.white, size: 16),
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
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.primary)),
            ),
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
        _buildInputField(colors),
        const SizedBox(height: 14),
        _buildTranslateButton(colors),
        const SizedBox(height: 14),
        _buildResultField(colors),
      ],
    );
  }

  Widget _buildInputField(CustomColors colors) {
    return Container(
      height: _inputFieldHeight,
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
                      Icons.edit,
                      color: _inputController.text.isNotEmpty
                          ? colors.primary
                          : colors.textLight,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '입력 텍스트',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
                          color: (_inputController.text.isNotEmpty
                              ? Colors.red.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.clear,
                          size: 16,
                          color: _inputController.text.isNotEmpty
                              ? Colors.red
                              : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _inputController.text.isNotEmpty
                              ? colors.primary.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.copy,
                          size: 16,
                          color: _inputController.text.isNotEmpty
                              ? colors.text
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: _inputController,
              readOnly: true,
              showCursor: false,
              onTap: () async {
                final result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const _InputFullScreenEditor(),
                    settings: RouteSettings(arguments: _inputController.text),
                  ),
                );
                if (result != null) {
                  setState(() {
                    _inputController.text = result;
                  });
                }
              },
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: '여기를 눌러 입력하세요',
                hintStyle: TextStyle(color: colors.textLight, fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              ),
              style: TextStyle(color: colors.text, fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslateButton(CustomColors colors) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            colors.primary.withOpacity(0.9),
            colors.secondary.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.transparent, width: 10),
          color: colors.white,
        ),
        margin: const EdgeInsets.all(3),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.translate, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.primary, colors.secondary],
                  ).createShader(bounds);
                },
                child: const Text(
                  '번역하기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
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

class _ResultFullScreenViewer extends StatelessWidget {
  final String text;
  final bool showPinyin;

  const _ResultFullScreenViewer({required this.text, required this.showPinyin});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colors = themeService.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translation_result),
      ),
      body: Stack(
        children: [
          Container(
            color: colors.white,
            width: double.infinity,
            height: double.infinity,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    text.isEmpty
                        ? AppLocalizations.of(context).translation_result_hint
                        : text,
                    style: TextStyle(
                      color: text.isEmpty ? colors.textLight : colors.text,
                      height: 1.6,
                      fontSize: 15,
                    ),
                  ),
                  if (showPinyin &&
                      RegExp(r'[\u3400-\u9FFF]').hasMatch(text)) ...[
                    const SizedBox(height: 12),
                    Divider(
                      height: 20,
                      color: colors.textLight.withValues(alpha: 0.4),
                      indent: 10,
                      endIndent: 10,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      PinyinHelper.getPinyin(
                        text,
                        format: PinyinFormat.WITH_TONE_MARK,
                      ),
                      style: TextStyle(
                        color: colors.textLight,
                        height: 1.6,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 90),
                ],
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
                        "${text.length}",
                        style: TextStyle(color: colors.text, fontSize: 14),
                      ),
                    ),
                    const Spacer(),
                    // 복사 버튼: 원형 버튼 스타일, 누르면 텍스트가 전체 복사됩니다.
                    ElevatedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: text));
                        Fluttertoast.showToast(
                          msg: AppLocalizations.of(context).input_text_copied,
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(2),
                        backgroundColor: colors.white,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(Icons.copy, color: colors.text, size: 24),
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
