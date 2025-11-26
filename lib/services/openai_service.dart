import 'dart:async';

import 'package:openai_dart/openai_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

typedef ChatDeltaCallback = void Function(String delta);
typedef ChatCompleteCallback = void Function();
typedef ChatErrorCallback = void Function(Object error);

class OpenAIService {
  static bool _isInitialized = false;
  static StreamSubscription? _subscription;
  static Timer? _noResponseTimer;
  static const Duration _noResponseTimeout = Duration(seconds: 10);
  static final String _proModel = "gpt-4.1-mini";
  static final String _freeModel = "gpt-4o-mini";
  static String get proModel => _proModel;
  static String get freeModel => _freeModel;

  static late OpenAIClient client;

  static void dispose() {
    _subscription?.cancel();
    _noResponseTimer?.cancel();
  }

  /// 진행 중인 스트리밍을 취소합니다. 이후에는 더 이상 델타가 전달되지 않습니다.
  static void cancelStreaming() {
    _subscription?.cancel();
    _subscription = null;
    _noResponseTimer?.cancel();
    _noResponseTimer = null;
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;

    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null) {
      throw Exception('OPENAI_API_KEY가 설정되지 않았습니다.');
    }

    _isInitialized = true;

    client = OpenAIClient(apiKey: apiKey);
  }

  static void translateText(
    String text,
    String fromLanguage,
    String toLanguage,
    String toneInstruction,
    bool usingProModel,
    ChatDeltaCallback onDelta,
    ChatCompleteCallback onComplete,
    ChatErrorCallback onError,
  ) async {
    try {
      final prompt =
          '''
다음 텍스트를 $fromLanguage에서 $toLanguage로 번역해주세요.
$toneInstruction

번역할 텍스트: "$text"

번역 결과만 출력하고 다른 설명은 포함하지 마세요.
''';

      final developerMessage = ChatCompletionMessage.developer(
        content: ChatCompletionDeveloperMessageContent.text(
          "You are a professional translator. Translate the given text accurately according to the specified tone and style. Respond only with the translated text without any additional comments or explanations.",
        ),
        role: ChatCompletionMessageRole.developer,
      );

      final userMessage = ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(prompt),
        role: ChatCompletionMessageRole.user,
      );

      /* // 프로 모델, 무료 모델 차등
      final res = usingProModel
          ? await client.createChatCompletion(
              request: CreateChatCompletionRequest(
                model: ChatCompletionModel.modelId(_proModel),
                messages: [developerMessage, userMessage],
              ),
            )
          : await client.createChatCompletion(
              request: CreateChatCompletionRequest(
                model: ChatCompletionModel.modelId(_freeModel),
                messages: [developerMessage, userMessage],
              ),
            ); */

      // 이전 진행 중인 스트림이 있다면 즉시 취소하여 지연을 방지
      _subscription?.cancel();

      // 프로 모델만 사용하는 경우
      final stream = client.createChatCompletionStream(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(_proModel),
          messages: [developerMessage, userMessage],
        ),
      );

      bool hasReceivedDelta = false;

      // 최초 응답(델타)이 일정 시간 내 오지 않으면 타임아웃 처리
      _noResponseTimer?.cancel();
      _noResponseTimer = Timer(_noResponseTimeout, () {
        if (!hasReceivedDelta) {
          _subscription?.cancel();
          _subscription = null;
          onError(
            TimeoutException(
              'No response within ${_noResponseTimeout.inSeconds}s',
            ),
          );
        }
      });

      _subscription = stream.listen(
        (event) {
          final deltaText = event.choices!.first.delta?.content ?? '';
          if (deltaText != '') {
            if (!hasReceivedDelta) {
              hasReceivedDelta = true;
              _noResponseTimer?.cancel();
              _noResponseTimer = null;
            }
            onDelta(deltaText.toString());
          }
        },
        onDone: () {
          _noResponseTimer?.cancel();
          _noResponseTimer = null;
          onComplete();
        },
        onError: (error) {
          _noResponseTimer?.cancel();
          _noResponseTimer = null;
          onError(error);
        },
      );
    } catch (e) {
      print('OpenAI API 호출 오류: $e');
    }
  }
}
