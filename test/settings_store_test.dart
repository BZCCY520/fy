import 'package:emby_media_player/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Emby settings defaults', () {
    const settings = EmbySettings.defaults;

    expect(settings.hasToken, isFalse);
    expect(settings.serverUrl, isEmpty);
    expect(settings.username, isEmpty);
  });

  test('Emby settings with token', () {
    const settings = EmbySettings(
      serverUrl: 'http://localhost:8096',
      username: 'testuser',
      userId: '12345',
      accessToken: 'test-token',
    );

    expect(settings.hasToken, isTrue);
    expect(settings.serverUrl, 'http://localhost:8096');
    expect(settings.username, 'testuser');
  });
}
