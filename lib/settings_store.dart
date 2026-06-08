import 'package:shared_preferences/shared_preferences.dart';

class TranslationSettings {
  const TranslationSettings({
    required this.endpoint,
    required this.apiKey,
    required this.model,
  });

  static const defaults = TranslationSettings(
    endpoint: 'https://api.openai.com/v1/chat/completions',
    apiKey: '',
    model: 'gpt-4.1-mini',
  );

  final String endpoint;
  final String apiKey;
  final String model;

  bool get isReady =>
      endpoint.trim().isNotEmpty && model.trim().isNotEmpty;

  TranslationSettings copyWith({
    String? endpoint,
    String? apiKey,
    String? model,
  }) {
    return TranslationSettings(
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }
}

class SettingsStore {
  static const _endpointKey = 'translator.endpoint';
  static const _apiKeyKey = 'translator.apiKey';
  static const _modelKey = 'translator.model';

  Future<TranslationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return TranslationSettings(
      endpoint:
          prefs.getString(_endpointKey) ??
          TranslationSettings.defaults.endpoint,
      apiKey:
          prefs.getString(_apiKeyKey) ?? TranslationSettings.defaults.apiKey,
      model: prefs.getString(_modelKey) ?? TranslationSettings.defaults.model,
    );
  }

  Future<void> save(TranslationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_endpointKey, settings.endpoint.trim()),
      prefs.setString(_apiKeyKey, settings.apiKey.trim()),
      prefs.setString(_modelKey, settings.model.trim()),
    ]);
  }
}
