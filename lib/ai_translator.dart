import 'dart:convert';

import 'package:http/http.dart' as http;

import 'language_option.dart';
import 'settings_store.dart';

class AiTranslator {
  AiTranslator({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> translate({
    required TranslationSettings settings,
    required String text,
    required LanguageOption sourceLanguage,
    required LanguageOption targetLanguage,
  }) async {
    final endpoint = settings.endpoint.trim();
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('翻译接口地址无效，请在设置中填写完整 URL。');
    }

    final body = <String, Object?>{
      'model': settings.model.trim(),
      'temperature': 0.1,
      'messages': [
        {
          'role': 'system',
          'content': [
            'You are a high-precision real-time speech translation engine.',
            'Translate faithfully, preserve meaning, tone, names, numbers, and units.',
            'Return only the translated text. Do not explain or add markdown.',
          ].join(' '),
        },
        {
          'role': 'user',
          'content': [
            'Source language: ${sourceLanguage.name} (${sourceLanguage.nativeName}).',
            'Target language: ${targetLanguage.name} (${targetLanguage.nativeName}).',
            'Text:',
            text,
          ].join('\n'),
        },
      ],
    };
    final headers = <String, String>{'Content-Type': 'application/json'};
    final apiKey = settings.apiKey.trim();
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await _client
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 45));

    final decodedText = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(decodedText, response.statusCode));
    }

    final decoded = jsonDecode(decodedText);
    final content = _extractAssistantContent(decoded);
    if (content == null || content.trim().isEmpty) {
      throw const FormatException('翻译接口返回格式无法识别。');
    }
    return content.trim();
  }

  String _extractErrorMessage(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic> && error['message'] != null) {
          return '翻译接口错误 $statusCode：${error['message']}';
        }
        if (decoded['message'] != null) {
          return '翻译接口错误 $statusCode：${decoded['message']}';
        }
      }
    } on FormatException {
      // Fall through to the compact raw body below.
    }
    final compactBody = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compactBody.isEmpty) {
      return '翻译接口错误 $statusCode。';
    }
    return '翻译接口错误 $statusCode：$compactBody';
  }

  String? _extractAssistantContent(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return null;
    }
    final firstChoice = choices.first;
    if (firstChoice is! Map<String, dynamic>) {
      return null;
    }

    final message = firstChoice['message'];
    if (message is Map<String, dynamic>) {
      final content = message['content'];
      if (content is String) {
        return content;
      }
      if (content is List) {
        return content
            .map((part) {
              if (part is Map<String, dynamic>) {
                return part['text']?.toString() ?? '';
              }
              return part.toString();
            })
            .join()
            .trim();
      }
    }

    final text = firstChoice['text'];
    return text is String ? text : null;
  }
}
