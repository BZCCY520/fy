import 'dart:convert';

import 'package:emby_media_player/emby_client.dart';
import 'package:emby_media_player/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('authenticates with Emby and extracts session fields', () async {
    late http.Request capturedRequest;
    final client = EmbyClient(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'AccessToken': 'token-123',
            'User': {'Id': 'user-1', 'Name': 'demo'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final session = await client.authenticate(
      serverUrl: 'http://emby.local:8096',
      username: 'demo',
      password: 'secret',
    );

    expect(
      capturedRequest.url.toString(),
      'http://emby.local:8096/emby/Users/AuthenticateByName',
    );
    expect(capturedRequest.headers['authorization'], contains('Emby Client='));
    expect(jsonDecode(capturedRequest.body), {
      'Username': 'demo',
      'Pw': 'secret',
    });
    expect(session.userId, 'user-1');
    expect(session.username, 'demo');
    expect(session.accessToken, 'token-123');
  });

  test('fetches video library items with token headers', () async {
    late http.Request capturedRequest;
    final client = EmbyClient(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'Items': [
              {
                'Id': 'episode-1',
                'Name': 'Pilot',
                'Type': 'Episode',
                'SeriesName': 'Demo Show',
                'ParentIndexNumber': 1,
                'IndexNumber': 2,
                'RunTimeTicks': 36000000000,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final videos = await client.fetchVideos(
      settings: const EmbySettings(
        serverUrl: 'https://example.com/emby',
        username: 'demo',
        userId: 'user-1',
        accessToken: 'token-123',
      ),
      searchTerm: 'pilot',
      limit: 12,
    );

    expect(capturedRequest.url.path, '/emby/Users/user-1/Items');
    expect(capturedRequest.url.queryParameters['SearchTerm'], 'pilot');
    expect(capturedRequest.url.queryParameters['Limit'], '12');
    expect(capturedRequest.headers['x-emby-token'], 'token-123');
    expect(videos, hasLength(1));
    expect(videos.single.displayTitle, 'Demo Show · S01E02 · Pilot');
    expect(videos.single.subtitle, 'Episode · 1小时0分钟');
  });

  test('builds playback urls from PlaybackInfo response', () async {
    final client = EmbyClient(
      client: MockClient((request) async {
        expect(request.url.path, '/emby/Items/movie-1/PlaybackInfo');
        return http.Response(
          jsonEncode({
            'PlaySessionId': 'play-session',
            'MediaSources': [
              {
                'Id': 'source-1',
                'Container': 'mkv',
                'MediaStreams': [
                  {'Type': 'Audio', 'Index': 1, 'IsDefault': true},
                ],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final source = await client.getPlaybackSource(
      settings: const EmbySettings(
        serverUrl: 'http://10.0.0.2:8096',
        username: 'demo',
        userId: 'user-1',
        accessToken: 'token-123',
      ),
      itemId: 'movie-1',
    );

    expect(
      source.directStreamUri.toString(),
      contains('/emby/Videos/movie-1/stream.mkv'),
    );
    expect(source.directStreamUri.queryParameters['api_key'], 'token-123');
    expect(source.directStreamUri.queryParameters['MediaSourceId'], 'source-1');
    expect(source.directStreamUri.queryParameters['AudioStreamIndex'], '1');
    expect(
      source.hlsStreamUri.toString(),
      contains('/emby/Videos/movie-1/master.m3u8'),
    );
    expect(source.headers['X-Emby-Token'], 'token-123');
  });
}
