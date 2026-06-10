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

  bool get isReady => endpoint.trim().isNotEmpty && model.trim().isNotEmpty;

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

class EmbySettings {
  const EmbySettings({
    required this.serverUrl,
    required this.username,
    required this.userId,
    required this.accessToken,
  });

  static const defaults = EmbySettings(
    serverUrl: '',
    username: '',
    userId: '',
    accessToken: '',
  );

  final String serverUrl;
  final String username;
  final String userId;
  final String accessToken;

  bool get hasToken =>
      serverUrl.trim().isNotEmpty &&
      userId.trim().isNotEmpty &&
      accessToken.trim().isNotEmpty;

  EmbySettings copyWith({
    String? serverUrl,
    String? username,
    String? userId,
    String? accessToken,
  }) {
    return EmbySettings(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      userId: userId ?? this.userId,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}

class SettingsStore {
  static const _endpointKey = 'translator.endpoint';
  static const _apiKeyKey = 'translator.apiKey';
  static const _modelKey = 'translator.model';
  static const _embyServerUrlKey = 'emby.serverUrl';
  static const _embyUsernameKey = 'emby.username';
  static const _embyUserIdKey = 'emby.userId';
  static const _embyAccessTokenKey = 'emby.accessToken';

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

  Future<EmbySettings> loadEmby() async {
    final prefs = await SharedPreferences.getInstance();
    return EmbySettings(
      serverUrl:
          prefs.getString(_embyServerUrlKey) ?? EmbySettings.defaults.serverUrl,
      username:
          prefs.getString(_embyUsernameKey) ?? EmbySettings.defaults.username,
      userId: prefs.getString(_embyUserIdKey) ?? EmbySettings.defaults.userId,
      accessToken:
          prefs.getString(_embyAccessTokenKey) ??
          EmbySettings.defaults.accessToken,
    );
  }

  Future<void> saveEmby(EmbySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_embyServerUrlKey, settings.serverUrl.trim()),
      prefs.setString(_embyUsernameKey, settings.username.trim()),
      prefs.setString(_embyUserIdKey, settings.userId.trim()),
      prefs.setString(_embyAccessTokenKey, settings.accessToken.trim()),
    ]);
  }
}
