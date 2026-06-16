import 'dart:convert';

import 'package:ai_subtitle_translator/ai_translator.dart';
import 'package:ai_subtitle_translator/language_option.dart';
import 'package:ai_subtitle_translator/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('does not send Authorization header when api key is empty', () async {
    late Map<String, String> capturedHeaders;
    final translator = AiTranslator(
      client: MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '你好'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await translator.translate(
      settings: const TranslationSettings(
        endpoint: 'http://localhost:8080/v1/chat/completions',
        apiKey: '',
        model: 'local-model',
      ),
      text: 'hello',
      sourceLanguage: appLanguages.firstWhere(
        (language) => language.code == 'en',
      ),
      targetLanguage: appLanguages.firstWhere(
        (language) => language.code == 'zh',
      ),
    );

    expect(result, '你好');
    expect(capturedHeaders['authorization'], isNull);
    expect(capturedHeaders['content-type'], contains('application/json'));
  });

  test('sends Bearer Authorization header when api key is present', () async {
    late Map<String, String> capturedHeaders;
    final translator = AiTranslator(
      client: MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '你好'},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await translator.translate(
      settings: const TranslationSettings(
        endpoint: 'http://localhost:8080/v1/chat/completions',
        apiKey: 'test-key',
        model: 'local-model',
      ),
      text: 'hello',
      sourceLanguage: appLanguages.firstWhere(
        (language) => language.code == 'en',
      ),
      targetLanguage: appLanguages.firstWhere(
        (language) => language.code == 'zh',
      ),
    );

    expect(capturedHeaders['authorization'], 'Bearer test-key');
  });
}
