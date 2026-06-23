import 'dart:convert';

import 'package:emby_media_player/emby_client.dart';
import 'package:emby_media_player/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const testSettings = EmbySettings(
    serverUrl: 'https://example.com/emby',
    username: 'demo',
    userId: 'user-1',
    accessToken: 'token-123',
  );

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
    expect(source.playSessionId, 'play-session');
    expect(source.mediaSourceId, 'source-1');
    // 该测试媒体源是 mkv 容器，不被原生播放器直连支持。
    expect(source.directPlaySupported, isFalse);
    expect(
      source.hlsStreamUri.toString(),
      contains('/emby/Videos/movie-1/master.m3u8'),
    );
    expect(source.headers['X-Emby-Token'], 'token-123');
  });

  test('marks mkv container as not direct-play supported', () async {
    final client = EmbyClient(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'PlaySessionId': 'play-session',
            'MediaSources': [
              {
                'Id': 'source-1',
                'Container': 'mkv',
                'MediaStreams': [
                  {'Type': 'Video', 'Index': 0, 'Codec': 'hevc'},
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
      settings: testSettings,
      itemId: 'movie-1',
    );

    expect(source.directPlaySupported, isFalse);
    expect(
      source.hlsStreamUri.toString(),
      contains('/emby/Videos/movie-1/master.m3u8'),
    );
  });

  test('fetches media details with user data and people', () async {
    late http.Request capturedRequest;
    final client = EmbyClient(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'Id': 'movie-1',
            'Name': 'Demo Movie',
            'Type': 'Movie',
            'Overview': 'A demo overview.',
            'ProductionYear': 2026,
            'RunTimeTicks': 72000000000,
            'CommunityRating': 8.6,
            'OfficialRating': 'PG-13',
            'Genres': ['Drama', 'Sci-Fi'],
            'Studios': [
              {'Name': 'Demo Studio'},
            ],
            'People': [
              {
                'Id': 'person-1',
                'Name': 'Actor One',
                'Role': 'Lead',
                'Type': 'Actor',
                'PrimaryImageTag': 'primary-tag',
              },
            ],
            'UserData': {
              'PlaybackPositionTicks': 9000000000,
              'PlayedPercentage': 12.5,
              'Played': false,
              'IsFavorite': true,
              'PlayCount': 2,
              'LastPlayedDate': '2026-06-17T12:00:00.0000000Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final details = await client.fetchMediaDetails(
      settings: testSettings,
      itemId: 'movie-1',
    );

    expect(capturedRequest.url.path, '/emby/Users/user-1/Items/movie-1');
    expect(capturedRequest.url.queryParameters['Fields'], contains('People'));
    expect(details.name, 'Demo Movie');
    expect(details.runtime, const Duration(hours: 2));
    expect(details.genres, ['Drama', 'Sci-Fi']);
    expect(details.studios, ['Demo Studio']);
    expect(details.people.single.name, 'Actor One');
    expect(details.people.single.primaryImageTag, 'primary-tag');
    expect(details.playbackPosition, const Duration(minutes: 15));
    expect(details.playedPercentage, 12.5);
    expect(details.isFavorite, isTrue);
    expect(details.playCount, 2);
  });

  test('builds person image url with size hints', () {
    final client = EmbyClient();

    final imageUrl = client.getImageUrl(
      serverUrl: 'https://example.com/emby',
      itemId: 'person-1',
      maxWidth: 160,
      maxHeight: 160,
    );

    final uri = Uri.parse(imageUrl);
    expect(uri.path, '/emby/Items/person-1/Images/Primary');
    expect(uri.queryParameters['maxWidth'], '160');
    expect(uri.queryParameters['maxHeight'], '160');
  });

  test('updates playback progress using ticks payload', () async {
    late http.Request capturedRequest;
    final client = EmbyClient(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 204);
      }),
    );

    await client.updatePlaybackProgress(
      settings: testSettings,
      itemId: 'movie-1',
      position: const Duration(minutes: 2),
      runtime: const Duration(hours: 1),
      isPaused: true,
      playSessionId: 'play-session',
      mediaSourceId: 'source-1',
    );

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/emby/Sessions/Playing/Progress');
    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(body['ItemId'], 'movie-1');
    expect(body['PositionTicks'], 1200000000);
    expect(body['RunTimeTicks'], 36000000000);
    expect(body['IsPaused'], isTrue);
    expect(body['PlaySessionId'], 'play-session');
    expect(body['MediaSourceId'], 'source-1');
  });

  test('reports playback start and stopped with session id', () async {
    final requests = <http.Request>[];
    final client = EmbyClient(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
    );

    await client.reportPlaybackStart(
      settings: testSettings,
      itemId: 'movie-1',
      position: const Duration(seconds: 30),
      playSessionId: 'play-session',
      mediaSourceId: 'source-1',
    );
    await client.reportPlaybackStopped(
      settings: testSettings,
      itemId: 'movie-1',
      position: const Duration(minutes: 5),
      playSessionId: 'play-session',
      mediaSourceId: 'source-1',
    );

    expect(requests[0].method, 'POST');
    expect(requests[0].url.path, '/emby/Sessions/Playing');
    final startBody = jsonDecode(requests[0].body) as Map<String, dynamic>;
    expect(startBody['ItemId'], 'movie-1');
    expect(startBody['PositionTicks'], 300000000);
    expect(startBody['PlaySessionId'], 'play-session');
    expect(startBody['MediaSourceId'], 'source-1');

    expect(requests[1].method, 'POST');
    expect(requests[1].url.path, '/emby/Sessions/Playing/Stopped');
    final stoppedBody = jsonDecode(requests[1].body) as Map<String, dynamic>;
    expect(stoppedBody['ItemId'], 'movie-1');
    expect(stoppedBody['PositionTicks'], 3000000000);
    expect(stoppedBody['PlaySessionId'], 'play-session');
  });

  test('marks played and toggles favorite endpoints', () async {
    final requests = <http.Request>[];
    final client = EmbyClient(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
    );

    await client.markPlayed(settings: testSettings, itemId: 'movie-1');
    await client.markPlayed(
      settings: testSettings,
      itemId: 'movie-1',
      played: false,
    );
    await client.setFavorite(
      settings: testSettings,
      itemId: 'movie-1',
      isFavorite: true,
    );
    await client.setFavorite(
      settings: testSettings,
      itemId: 'movie-1',
      isFavorite: false,
    );

    expect(requests.map((request) => request.method), [
      'POST',
      'DELETE',
      'POST',
      'DELETE',
    ]);
    expect(requests[0].url.path, '/emby/Users/user-1/PlayedItems/movie-1');
    expect(requests[2].url.path, '/emby/Users/user-1/FavoriteItems/movie-1');
  });

  test('fetches recommendations and filters current item', () async {
    late http.Request capturedRequest;
    final client = EmbyClient(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'Items': [
              {'Id': 'movie-1', 'Name': 'Current', 'Type': 'Movie'},
              {'Id': 'movie-2', 'Name': 'Related', 'Type': 'Movie'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final items = await client.getRecommendations(
      settings: testSettings,
      itemId: 'movie-1',
      limit: 6,
    );

    expect(capturedRequest.url.path, '/emby/Items/movie-1/Similar');
    expect(capturedRequest.url.queryParameters['UserId'], 'user-1');
    expect(capturedRequest.url.queryParameters['Limit'], '6');
    expect(items, hasLength(1));
    expect(items.single.id, 'movie-2');
  });
}
