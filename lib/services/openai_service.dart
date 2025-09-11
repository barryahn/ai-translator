import 'dart:async';

import 'package:openai_dart/openai_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

typedef ChatDeltaCallback = void Function(String delta);
typedef ChatCompleteCallback = void Function();
typedef ChatErrorCallback = void Function(Object error);

class OpenAIService {
  static bool _isInitialized = false;
  static StreamSubscription? _subscription;
  static final String _proModel = "gpt-4.1-mini";
  static final String _freeModel = "gpt-4o-mini";
  static String get proModel => _proModel;
  static String get freeModel => _freeModel;

  static late OpenAIClient client;

  static void dispose() {
    _subscription?.cancel();
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

      _subscription = stream.listen(
        (event) {
          final deltaText = event.choices!.first.delta?.content ?? '';
          if (deltaText != '') onDelta(deltaText.toString());
        },
        onDone: onComplete,
        onError: onError,
      );
    } catch (e) {
      print('OpenAI API 호출 오류: $e');
    }
  }
}
