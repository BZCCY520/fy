import 'package:flutter/services.dart';

class LiveActivityBridge {
  static const _channel = MethodChannel('ai_voice_translator/live_activity');

  Future<void> configureAudioSession() async {
    try {
      await _channel.invokeMethod<void>('configureAudioSession');
    } on PlatformException {
      // Native bridge is optional on non-iOS hosts and in widget tests.
    } on MissingPluginException {
      // Native bridge is optional on non-iOS hosts and in widget tests.
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

  Future<void> end() async {
    await _safeInvoke('end');
  }

  Future<void> _safeInvoke(String method, [Map<String, Object?>? args]) async {
    try {
      await _channel.invokeMethod<Object?>(method, args);
    } on PlatformException {
      // Live Activities require a signed iOS app + Widget extension; the
      // Flutter UI remains functional if the native capability is unavailable.
    } on MissingPluginException {
      // Non-iOS hosts and tests do not register this channel.
    }
  }
}
