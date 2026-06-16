import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settings_store.dart';

class EmbyAuthSession {
  const EmbyAuthSession({
    required this.userId,
    required this.username,
    required this.accessToken,
  });

  final String userId;
  final String username;
  final String accessToken;
}

class EmbyVideoItem {
  const EmbyVideoItem({
    required this.id,
    required this.name,
    required this.type,
    this.seriesName,
    this.seasonNumber,
    this.episodeNumber,
    this.productionYear,
    this.runtime,
  });

  final String id;
  final String name;
  final String type;
  final String? seriesName;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? productionYear;
  final Duration? runtime;

  String get displayTitle {
    if (seriesName != null && seriesName!.trim().isNotEmpty) {
      final parts = <String>[seriesName!.trim()];
      if (seasonNumber != null || episodeNumber != null) {
        final season = seasonNumber == null
            ? ''
            : 'S${seasonNumber!.toString().padLeft(2, '0')}';
        final episode = episodeNumber == null
            ? ''
            : 'E${episodeNumber!.toString().padLeft(2, '0')}';
        parts.add('$season$episode');
      }
      if (name.trim().isNotEmpty) {
        parts.add(name.trim());
      }
      return parts.join(' · ');
    }
    if (productionYear != null && name.trim().isNotEmpty) {
      return '${name.trim()} (${productionYear!})';
    }
    return name.trim().isEmpty ? id : name.trim();
  }

  String get subtitle {
    final parts = <String>[
      if (type.trim().isNotEmpty) type.trim(),
      if (runtime != null) _formatRuntime(runtime!),
    ];
    return parts.join(' · ');
  }

  static String _formatRuntime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours小时$minutes分钟';
    }
    return '$minutes分钟';
  }
}

class EmbyPlaybackSource {
  const EmbyPlaybackSource({
    required this.directStreamUri,
    required this.headers,
    this.hlsStreamUri,
  });

  final Uri directStreamUri;
  final Uri? hlsStreamUri;
  final Map<String, String> headers;
}

class EmbyClient {
  EmbyClient({http.Client? client}) : _client = client ?? http.Client();

  static const _clientName = 'AI Voice Translator';
  static const _deviceName = 'Flutter';
  static const _deviceId = 'ai_voice_translator_flutter';
  static const _version = '1.0.0';

  final http.Client _client;

  Future<EmbyAuthSession> authenticate({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final uri = _apiUri(serverUrl, ['Users', 'AuthenticateByName']);
    final response = await _client
        .post(
          uri,
          headers: _anonymousHeaders(),
          body: jsonEncode({'Username': username.trim(), 'Pw': password}),
        )
        .timeout(const Duration(seconds: 30));

    final decodedText = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(decodedText, response.statusCode));
    }

    final decoded = jsonDecode(decodedText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Emby 登录响应格式无法识别。');
    }
    final accessToken = decoded['AccessToken']?.toString() ?? '';
    final user = decoded['User'];
    final userId = user is Map<String, dynamic> ? user['Id']?.toString() : null;
    final resolvedName = user is Map<String, dynamic>
        ? user['Name']?.toString()
        : username.trim();

    if (accessToken.isEmpty || userId == null || userId.isEmpty) {
      throw const FormatException('Emby 登录成功，但响应中没有用户 ID 或 Token。');
    }
    return EmbyAuthSession(
      userId: userId,
      username: (resolvedName == null || resolvedName.isEmpty)
          ? username.trim()
          : resolvedName,
      accessToken: accessToken,
    );
  }

  Future<List<EmbyVideoItem>> fetchVideos({
    required EmbySettings settings,
    String? searchTerm,
    int limit = 60,
  }) async {
    _ensureAuthorized(settings);
    final query = <String, String>{
      'Recursive': 'true',
      'IncludeItemTypes': 'Movie,Episode,Video',
      'SortBy': 'DateCreated,SortName',
      'SortOrder': 'Descending',
      'Limit': limit.toString(),
      'Fields':
          'MediaSources,Overview,SeriesName,ParentIndexNumber,IndexNumber,RunTimeTicks,ProductionYear',
      if (searchTerm != null && searchTerm.trim().isNotEmpty)
        'SearchTerm': searchTerm.trim(),
    };
    final uri = _apiUri(settings.serverUrl, [
      'Users',
      settings.userId.trim(),
      'Items',
    ], query);
    final response = await _client
        .get(uri, headers: _authorizedHeaders(settings.accessToken))
        .timeout(const Duration(seconds: 30));

    final decodedText = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(decodedText, response.statusCode));
    }

    final decoded = jsonDecode(decodedText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Emby 媒体库响应格式无法识别。');
    }
    final items = decoded['Items'];
    if (items is! List) {
      return const [];
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(_parseVideoItem)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<EmbyPlaybackSource> getPlaybackSource({
    required EmbySettings settings,
    required String itemId,
  }) async {
    _ensureAuthorized(settings);
    final token = settings.accessToken.trim();
    final playbackInfoUri = _apiUri(
      settings.serverUrl,
      ['Items', itemId, 'PlaybackInfo'],
      {'UserId': settings.userId.trim()},
    );

    Map<String, dynamic>? mediaSource;
    String? playSessionId;
    try {
      final response = await _client
          .get(playbackInfoUri, headers: _authorizedHeaders(token))
          .timeout(const Duration(seconds: 30));
      final decodedText = utf8.decode(response.bodyBytes);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(decodedText);
        if (decoded is Map<String, dynamic>) {
          playSessionId = decoded['PlaySessionId']?.toString();
          final mediaSources = decoded['MediaSources'];
          if (mediaSources is List && mediaSources.isNotEmpty) {
            final first = mediaSources.first;
            if (first is Map<String, dynamic>) {
              mediaSource = first;
            }
          }
        }
      }
    } on Object {
      // PlaybackInfo is a compatibility optimization. If it fails, fall back to
      // the canonical stream URL built from the item id and token.
    }

    final mediaSourceId = mediaSource?['Id']?.toString();
    final directStreamUrl = mediaSource?['DirectStreamUrl']?.toString();
    final container = _safeContainer(mediaSource?['Container']?.toString());
    final audioStreamIndex = _defaultAudioStreamIndex(mediaSource);

    // 构建直接流 URL，优先使用服务器返回的 DirectStreamUrl
    final directQuery = <String, String>{'Static': 'true', 'api_key': token};
    if (mediaSourceId != null && mediaSourceId.isNotEmpty) {
      directQuery['MediaSourceId'] = mediaSourceId;
    }
    if (playSessionId != null && playSessionId.isNotEmpty) {
      directQuery['PlaySessionId'] = playSessionId;
    }
    if (audioStreamIndex != null) {
      directQuery['AudioStreamIndex'] = audioStreamIndex;
    }

    final directUri = directStreamUrl != null && directStreamUrl.isNotEmpty
        ? _withToken(
            _resolveEmbyUri(settings.serverUrl, directStreamUrl),
            token,
          )
        : _apiUri(settings.serverUrl, [
            'Videos',
            itemId,
            'stream.${container ?? 'mp4'}',
          ], directQuery);

    // HLS 流作为备选方案（某些设备上兼容性较差）
    final hlsQuery = <String, String>{
      'api_key': token,
      'VideoCodec': 'h264',
      'AudioCodec': 'aac',
      'MaxAudioChannels': '2',
      'StartTimeTicks': '0',
    };
    if (mediaSourceId != null && mediaSourceId.isNotEmpty) {
      hlsQuery['MediaSourceId'] = mediaSourceId;
    }
    if (playSessionId != null && playSessionId.isNotEmpty) {
      hlsQuery['PlaySessionId'] = playSessionId;
    }
    if (audioStreamIndex != null) {
      hlsQuery['AudioStreamIndex'] = audioStreamIndex;
    }

    return EmbyPlaybackSource(
      directStreamUri: directUri,
      hlsStreamUri: _apiUri(settings.serverUrl, [
        'Videos',
        itemId,
        'master.m3u8',
      ], hlsQuery),
      headers: {
        'X-Emby-Token': token,
        'X-MediaBrowser-Token': token,
        'Accept': '*/*',
      },
    );
  }

  EmbyVideoItem _parseVideoItem(Map<String, dynamic> item) {
    return EmbyVideoItem(
      id: item['Id']?.toString() ?? '',
      name: item['Name']?.toString() ?? '',
      type: item['Type']?.toString() ?? '',
      seriesName: item['SeriesName']?.toString(),
      seasonNumber: _asInt(item['ParentIndexNumber']),
      episodeNumber: _asInt(item['IndexNumber']),
      productionYear: _asInt(item['ProductionYear']),
      runtime: _runtimeFromTicks(item['RunTimeTicks']),
    );
  }

  Uri _apiUri(
    String serverUrl,
    List<String> segments, [
    Map<String, String>? queryParameters,
  ]) {
    final base = _apiBaseUri(serverUrl);
    return base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        ...segments,
      ],
      queryParameters: _compactQuery(queryParameters),
      fragment: null,
    );
  }

  Uri _apiBaseUri(String serverUrl) {
    final trimmed = serverUrl.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null ||
        !parsed.hasScheme ||
        parsed.host.isEmpty ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      throw const FormatException(
        'Emby 服务器地址无效，请填写 http://host:8096 或 https://host/emby。',
      );
    }
    final pathSegments = parsed.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: true);
    if (pathSegments.isEmpty) {
      pathSegments.add('emby');
    }
    return parsed.replace(
      pathSegments: pathSegments,
      query: null,
      fragment: null,
    );
  }

  Uri _resolveEmbyUri(String serverUrl, String pathOrUrl) {
    final parsed = Uri.tryParse(pathOrUrl);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }
    final base = _apiBaseUri(serverUrl);
    if (parsed == null) {
      return base;
    }
    final basePrefix = '/${base.pathSegments.join('/')}';
    final sourcePath = parsed.path;
    final resolvedPath =
        sourcePath.startsWith('/emby/') || sourcePath.startsWith(basePrefix)
        ? sourcePath
        : [
            ...base.pathSegments.where((segment) => segment.isNotEmpty),
            ...parsed.pathSegments.where((segment) => segment.isNotEmpty),
          ].join('/');
    return base.replace(
      path: resolvedPath.startsWith('/') ? resolvedPath : '/$resolvedPath',
      query: parsed.query,
      fragment: null,
    );
  }

  Uri _withToken(Uri uri, String token) {
    final query = Map<String, String>.from(uri.queryParameters);
    query.putIfAbsent('api_key', () => token);
    return uri.replace(queryParameters: query);
  }

  Map<String, String> _anonymousHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': _authorizationHeader,
      'X-Emby-Authorization': _authorizationHeader,
    };
  }

  Map<String, String> _authorizedHeaders(String token) {
    return {
      'Accept': 'application/json',
      'Authorization': _authorizationHeader,
      'X-Emby-Authorization': _authorizationHeader,
      'X-Emby-Token': token.trim(),
      'X-MediaBrowser-Token': token.trim(),
    };
  }

  String get _authorizationHeader =>
      'Emby Client="$_clientName", Device="$_deviceName", '
      'DeviceId="$_deviceId", Version="$_version"';

  Map<String, String>? _compactQuery(Map<String, String>? query) {
    if (query == null || query.isEmpty) {
      return null;
    }
    return {
      for (final entry in query.entries)
        if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
    };
  }

  String _extractErrorMessage(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['ErrorMessage'] ?? decoded['Message'];
        if (error != null) {
          return 'Emby 接口错误 $statusCode：$error';
        }
      }
    } on FormatException {
      // Fall through to the compact raw body below.
    }
    final compactBody = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compactBody.isEmpty
        ? 'Emby 接口错误 $statusCode。'
        : 'Emby 接口错误 $statusCode：$compactBody';
  }

  void _ensureAuthorized(EmbySettings settings) {
    if (!settings.hasToken) {
      throw const FormatException('请先连接 Emby 并完成登录。');
    }
  }

  String? _safeContainer(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final first = value
        .split(',')
        .map((part) => part.trim().toLowerCase())
        .firstWhere((part) => part.isNotEmpty, orElse: () => 'mp4');
    return first.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String? _defaultAudioStreamIndex(Map<String, dynamic>? mediaSource) {
    final mediaStreams = mediaSource?['MediaStreams'];
    if (mediaStreams is! List) {
      return null;
    }
    for (final stream in mediaStreams) {
      if (stream is! Map<String, dynamic>) {
        continue;
      }
      final type = stream['Type']?.toString().toLowerCase();
      final isDefault = stream['IsDefault'] == true;
      final index = stream['Index'];
      if (type == 'audio' && isDefault && index != null) {
        return index.toString();
      }
    }
    return null;
  }

  Duration? _runtimeFromTicks(Object? value) {
    final ticks = _asInt(value);
    if (ticks == null || ticks <= 0) {
      return null;
    }
    return Duration(microseconds: ticks ~/ 10);
  }

  int? _asInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }
}
