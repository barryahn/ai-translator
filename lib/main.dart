import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:provider/provider.dart';
import 'services/theme_service.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final background = Theme.of(context).scaffoldBackgroundColor;
    final text = colorScheme.onBackground;
    final textLight = Colors.grey;
    final white = Colors.white;
    final primary = colorScheme.primary;
    final secondary = colorScheme.secondary;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          '번역',
          style: TextStyle(color: text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              _buildLanguageSelector(
                text: text,
                textLight: textLight,
                primary: primary,
                background: background,
                white: white,
              ),
              const SizedBox(height: 20),
              _buildTonePicker(
                text: text,
                textLight: textLight,
                primary: primary,
                white: white,
                background: background,
              ),
              const SizedBox(height: 10),
              _buildTranslationArea(
                text: text,
                textLight: textLight,
                primary: primary,
                secondary: secondary,
                white: white,
                background: background,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector({
    required Color text,
    required Color textLight,
    required Color primary,
    required Color background,
    required Color white,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 5,
          child: _buildFromLanguageDropdown(
            text,
            textLight,
            primary,
            background,
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(child: _buildLanguageSwapButton(primary, white)),
        ),
        Expanded(
          flex: 5,
          child: _buildToLanguageDropdown(text, textLight, primary, background),
        ),
      ],
    );
  }

  Widget _buildFromLanguageDropdown(
    Color text,
    Color textLight,
    Color primary,
    Color background,
  ) {
    return SizedBox(
      width: double.infinity,
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          hint: Text(
            'Select Item',
            style: TextStyle(fontSize: 14, color: textLight),
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
                            color: text,
                            height: 1.1,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (name == selectedFromLanguage)
                        Icon(Icons.check, size: 16, color: primary),
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
                        color: text,
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
              child: Icon(Icons.arrow_drop_down, size: 18, color: textLight),
            ),
            openMenuIcon: SizedBox(
              width: 14,
              child: Icon(Icons.arrow_drop_up, size: 18, color: textLight),
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
              border: Border(bottom: BorderSide(color: primary)),
            ),
          ),
          menuItemStyleData: const MenuItemStyleData(height: 46),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSwapButton(Color primary, Color white) {
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
          color: primary,
          shape: BoxShape.rectangle,
        ),
        child: Center(
          child: Icon(Icons.arrow_forward_ios, color: white, size: 16),
        ),
      ),
    );
  }

  Widget _buildToLanguageDropdown(
    Color text,
    Color textLight,
    Color primary,
    Color background,
  ) {
    return SizedBox(
      width: double.infinity,
      child: DropdownButtonHideUnderline(
        child: DropdownButton2<String>(
          isExpanded: true,
          hint: Text(
            'Select Item',
            style: TextStyle(fontSize: 14, color: textLight),
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
                            color: text,
                            height: 1.1,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (name == selectedToLanguage)
                        Icon(Icons.check, size: 16, color: primary),
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
                        color: text,
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
              child: Icon(Icons.arrow_drop_down, size: 18, color: textLight),
            ),
            openMenuIcon: SizedBox(
              width: 14,
              child: Icon(Icons.arrow_drop_up, size: 18, color: textLight),
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
              border: Border(bottom: BorderSide(color: primary)),
            ),
          ),
          menuItemStyleData: const MenuItemStyleData(height: 46),
          dropdownStyleData: DropdownStyleData(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTonePicker({
    required Color text,
    required Color textLight,
    required Color primary,
    required Color white,
    required Color background,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: white,
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
                      Icon(Icons.tune, color: primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '번역 톤',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: text,
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
                                  color: textLight,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Container(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.check_circle,
                                  color: textLight,
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
                        color: text,
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
                      activeTrackColor: textLight,
                      inactiveTrackColor: background,
                      thumbColor: textLight,
                      overlayColor: primary.withOpacity(0.2),
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
                                color: isSelected ? primary : textLight,
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
                                color: isSelected ? primary : textLight,
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

  Widget _buildTranslationArea({
    required Color text,
    required Color textLight,
    required Color primary,
    required Color secondary,
    required Color white,
    required Color background,
  }) {
    return Column(
      children: [
        _buildInputField(text, textLight, primary, white),
        const SizedBox(height: 14),
        _buildTranslateButton(primary, secondary, white),
        const SizedBox(height: 14),
        _buildResultField(text, textLight, primary, white),
      ],
    );
  }

  Widget _buildInputField(
    Color text,
    Color textLight,
    Color primary,
    Color white,
  ) {
    return Container(
      height: _inputFieldHeight,
      decoration: BoxDecoration(
        color: white,
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
                          ? primary
                          : textLight,
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
                              ? primary.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.copy,
                          size: 16,
                          color: _inputController.text.isNotEmpty
                              ? text
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
              onTap: () {},
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: '여기를 눌러 입력하세요',
                hintStyle: TextStyle(color: textLight, fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              ),
              style: TextStyle(color: text, fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslateButton(Color primary, Color secondary, Color white) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [primary.withOpacity(0.9), secondary.withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.transparent, width: 10),
          color: white,
        ),
        margin: const EdgeInsets.all(3),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.translate, color: primary, size: 20),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primary, secondary],
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

  Widget _buildResultField(
    Color text,
    Color textLight,
    Color primary,
    Color white,
  ) {
    return Container(
      height: _resultFieldHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: white,
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
                      color: _translatedText.isEmpty ? textLight : primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '번역 결과',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _translatedText.isEmpty ? textLight : text,
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
                              ? primary.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.copy,
                          size: 16,
                          color: (_translatedText.isNotEmpty
                              ? text
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
                        color: _translatedText.isEmpty ? textLight : text,
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
