import 'package:emby_media_player/native_player_bridge.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('emby_media_player/native_player');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('reads subtitle tracks from native bridge', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getSubtitleTracks');
      return [
        {
          'index': -1,
          'id': 'off',
          'displayName': '关闭字幕',
          'languageCode': '',
          'isSelected': false,
          'isOff': true,
        },
        {
          'index': 0,
          'id': 'zh',
          'displayName': '中文',
          'languageCode': 'zh-Hans',
          'isSelected': true,
          'isOff': false,
        },
      ];
    });

    final tracks = await NativePlayerBridge.getSubtitleTracks();

    expect(tracks, hasLength(2));
    expect(tracks.first['isOff'], isTrue);
    expect(tracks.last['displayName'], '中文');
    expect(tracks.last['isSelected'], isTrue);
  });

  test('selects subtitle track through native bridge', () async {
    MethodCall? capturedCall;
    messenger.setMockMethodCallHandler(channel, (call) async {
      capturedCall = call;
      return true;
    });

    await NativePlayerBridge.selectSubtitleTrack(-1);

    expect(capturedCall?.method, 'selectSubtitleTrack');
    expect(capturedCall?.arguments, {'trackIndex': -1});
  });

  test('reads audio tracks defensively from native bridge', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getAudioTracks');
      return [
        {'index': 0, 'displayName': 'English', 'isSelected': true},
        'unexpected',
      ];
    });

    final tracks = await NativePlayerBridge.getAudioTracks();

    expect(tracks, hasLength(1));
    expect(tracks.single['displayName'], 'English');
  });
}
