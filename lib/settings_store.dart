import 'package:shared_preferences/shared_preferences.dart';

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
  static const _embyServerUrlKey = 'emby.serverUrl';
  static const _embyUsernameKey = 'emby.username';
  static const _embyUserIdKey = 'emby.userId';
  static const _embyAccessTokenKey = 'emby.accessToken';

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
