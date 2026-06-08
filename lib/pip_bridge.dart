import 'package:flutter/services.dart';

class PipBridge {
  static const _channel = MethodChannel('ai_voice_translator/pip');

  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> start({
    required String sourceLanguage,
    required String targetLanguage,
    required String status,
    String transcript = '',
    String translation = '',
  }) async {
    await _safeInvoke('start', {
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'status': status,
      'transcript': transcript,
      'translation': translation,
    });
  }

  Future<void> update({
    required String sourceLanguage,
    required String targetLanguage,
    required String status,
    String transcript = '',
    String translation = '',
  }) async {
    await _safeInvoke('update', {
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'status': status,
      'transcript': transcript,
      'translation': translation,
    });
  }

  Future<void> stop() async {
    await _safeInvoke('stop');
  }

  Future<void> _safeInvoke(String method, [Map<String, Object?>? args]) async {
    try {
      await _channel.invokeMethod<Object?>(method, args);
    } on PlatformException {
      // PiP requires iOS runtime support and a signed app. Keep Flutter UI usable
      // if the native feature is unavailable.
    } on MissingPluginException {
      // Non-iOS hosts and widget tests do not register this channel.
    }
  }
}
