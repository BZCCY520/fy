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

class EmbyPerson {
  const EmbyPerson({
    required this.id,
    required this.name,
    this.role,
    this.type,
    this.primaryImageTag,
  });

  final String id;
  final String name;
  final String? role;
  final String? type;
  final String? primaryImageTag;
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
    this.overview,
    this.communityRating,
    this.imageBlurHash,
    this.officialRating,
    this.genres = const [],
    this.studios = const [],
    this.people = const [],
    this.playbackPosition,
    this.playedPercentage,
    this.isPlayed,
    this.isFavorite,
    this.playCount,
    this.lastPlayedDate,
  });

  final String id;
  final String name;
  final String type;
  final String? seriesName;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? productionYear;
  final Duration? runtime;
  final String? overview;
  final double? communityRating;
  final String? imageBlurHash;
  final String? officialRating;
  final List<String> genres;
  final List<String> studios;
  final List<EmbyPerson> people;
  final Duration? playbackPosition;
  final double? playedPercentage;
  final bool? isPlayed;
  final bool? isFavorite;
  final int? playCount;
  final DateTime? lastPlayedDate;

  EmbyVideoItem copyWith({
    String? id,
    String? name,
    String? type,
    String? seriesName,
    int? seasonNumber,
    int? episodeNumber,
    int? productionYear,
    Duration? runtime,
    String? overview,
    double? communityRating,
    String? imageBlurHash,
    String? officialRating,
    List<String>? genres,
    List<String>? studios,
    List<EmbyPerson>? people,
    Duration? playbackPosition,
    double? playedPercentage,
    bool? isPlayed,
    bool? isFavorite,
    int? playCount,
    DateTime? lastPlayedDate,
  }) {
    return EmbyVideoItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      seriesName: seriesName ?? this.seriesName,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      productionYear: productionYear ?? this.productionYear,
      runtime: runtime ?? this.runtime,
      overview: overview ?? this.overview,
      communityRating: communityRating ?? this.communityRating,
      imageBlurHash: imageBlurHash ?? this.imageBlurHash,
      officialRating: officialRating ?? this.officialRating,
      genres: genres ?? this.genres,
      studios: studios ?? this.studios,
      people: people ?? this.people,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      playedPercentage: playedPercentage ?? this.playedPercentage,
      isPlayed: isPlayed ?? this.isPlayed,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      lastPlayedDate: lastPlayedDate ?? this.lastPlayedDate,
    );
  }

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
    this.playSessionId,
    this.mediaSourceId,
    this.directPlaySupported = true,
  });

  final Uri directStreamUri;
  final Uri? hlsStreamUri;
  final Map<String, String> headers;

  /// Emby 为本次播放分配的会话 ID，用于贯穿 Sessions/Playing 生命周期上报。
  final String? playSessionId;

  /// 实际使用的媒体源 ID，进度上报时一并回传给服务器。
  final String? mediaSourceId;

  /// 直连流是否能被 iOS 原生播放器直接播放。
  ///
  /// 对于 AVPlayer 不支持的容器（如 mkv / avi / flv），应直接走 HLS 转码流，
  /// 避免在原生侧等待加载失败再回退，提升首帧速度。
  final bool directPlaySupported;
}

class EmbyClient {
  EmbyClient({http.Client? client}) : _client = client ?? http.Client();

  static const _clientName = 'Emby Media Player';
  static const _deviceName = 'Flutter';
  static const _deviceId = 'emby_media_player_flutter';
  static const _version = '3.0.0';

  final http.Client _client;

  /// 获取媒体项的图片 URL
  ///
  /// [serverUrl] Emby 服务器地址
  /// [itemId] 媒体项 ID
  /// [imageType] 图片类型: Primary, Backdrop, Logo, etc.
  /// [maxWidth] 最大宽度
  /// [maxHeight] 最大高度
  /// [quality] 图片质量 (1-100)
  String getImageUrl({
    required String serverUrl,
    required String itemId,
    String imageType = 'Primary',
    int? maxWidth,
    int? maxHeight,
    int quality = 90,
  }) {
    final query = <String, String>{'quality': quality.toString()};
    if (maxWidth != null) query['maxWidth'] = maxWidth.toString();
    if (maxHeight != null) query['maxHeight'] = maxHeight.toString();

    return _apiUri(serverUrl, [
      'Items',
      itemId,
      'Images',
      imageType,
    ], query).toString();
  }

  /// 获取海报 URL（Primary 图片）
  String getPosterUrl({
    required String serverUrl,
    required String itemId,
    int? width,
  }) {
    return getImageUrl(
      serverUrl: serverUrl,
      itemId: itemId,
      imageType: 'Primary',
      maxWidth: width ?? 500,
    );
  }

  /// 获取背景图 URL（Backdrop 图片）
  String? getBackdropUrl({
    required String serverUrl,
    required String itemId,
    int? width,
  }) {
    return getImageUrl(
      serverUrl: serverUrl,
      itemId: itemId,
      imageType: 'Backdrop',
      maxWidth: width ?? 1920,
    );
  }

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
          'MediaSources,Overview,SeriesName,ParentIndexNumber,IndexNumber,RunTimeTicks,ProductionYear,CommunityRating,UserData',
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

  Future<EmbyVideoItem> fetchMediaDetails({
    required EmbySettings settings,
    required String itemId,
  }) async {
    _ensureAuthorized(settings);
    final uri = _apiUri(
      settings.serverUrl,
      ['Users', settings.userId.trim(), 'Items', itemId],
      {
        'Fields':
            'Overview,Genres,Studios,People,ProductionYear,RunTimeTicks,CommunityRating,OfficialRating,UserData,ParentIndexNumber,IndexNumber,SeriesName',
      },
    );
    final response = await _client
        .get(uri, headers: _authorizedHeaders(settings.accessToken))
        .timeout(const Duration(seconds: 30));

    final decodedText = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(decodedText, response.statusCode));
    }

    final decoded = jsonDecode(decodedText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Emby 媒体详情响应格式无法识别。');
    }

    return _parseVideoItem(decoded);
  }

  Future<Duration?> getResumePoint({
    required EmbySettings settings,
    required String itemId,
  }) async {
    final details = await fetchMediaDetails(settings: settings, itemId: itemId);
    return details.playbackPosition;
  }

  Future<void> updatePlaybackProgress({
    required EmbySettings settings,
    required String itemId,
    required Duration position,
    Duration? runtime,
    bool isPaused = false,
    String? playSessionId,
    String? mediaSourceId,
  }) async {
    _ensureAuthorized(settings);
    final uri = _apiUri(settings.serverUrl, [
      'Sessions',
      'Playing',
      'Progress',
    ]);
    final response = await _client
        .post(
          uri,
          headers: _jsonAuthorizedHeaders(settings.accessToken),
          body: jsonEncode({
            'ItemId': itemId,
            'PositionTicks': _durationToTicks(position),
            if (runtime != null) 'RunTimeTicks': _durationToTicks(runtime),
            'IsPaused': isPaused,
            'CanSeek': true,
            if (playSessionId != null && playSessionId.isNotEmpty)
              'PlaySessionId': playSessionId,
            if (mediaSourceId != null && mediaSourceId.isNotEmpty)
              'MediaSourceId': mediaSourceId,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decodedText = utf8.decode(response.bodyBytes);
      throw Exception(_extractErrorMessage(decodedText, response.statusCode));
    }
  }

  /// 上报播放开始事件（Sessions/Playing）。
  ///
  /// 让 Emby 服务器在"正在播放"列表中记录本次会话，并支持后续的进度
  /// 同步和停止上报形成完整生命周期。
  Future<void> reportPlaybackStart({
    required EmbySettings settings,
    required String itemId,
    Duration position = Duration.zero,
    String? playSessionId,
    String? mediaSourceId,
  }) async {
    _ensureAuthorized(settings);
    final uri = _apiUri(settings.serverUrl, ['Sessions', 'Playing']);
    final response = await _client
        .post(
          uri,
          headers: _jsonAuthorizedHeaders(settings.accessToken),
          body: jsonEncode({
            'ItemId': itemId,
            'PositionTicks': _durationToTicks(position),
            'IsPaused': false,
            'CanSeek': true,
            'PlayMethod': 'DirectStream',
            if (playSessionId != null && playSessionId.isNotEmpty)
              'PlaySessionId': playSessionId,
            if (mediaSourceId != null && mediaSourceId.isNotEmpty)
              'MediaSourceId': mediaSourceId,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decodedText = utf8.decode(response.bodyBytes);
      throw Exception(_extractErrorMessage(decodedText, response.statusCode));
    }
  }

  /// 上报播放停止事件（Sessions/Playing/Stopped）。
  ///
  /// 在离开播放界面或播放结束时调用，写入最终续播位置并结束会话。
  Future<void> reportPlaybackStopped({
    required EmbySettings settings,
    required String itemId,
    required Duration position,
    String? playSessionId,
    String? mediaSourceId,
  }) async {
    _ensureAuthorized(settings);
    final uri = _apiUri(settings.serverUrl, ['Sessions', 'Playing', 'Stopped']);
    final response = await _client
        .post(
          uri,
          headers: _jsonAuthorizedHeaders(settings.accessToken),
          body: jsonEncode({
            'ItemId': itemId,
            'PositionTicks': _durationToTicks(position),
            if (playSessionId != null && playSessionId.isNotEmpty)
              'PlaySessionId': playSessionId,
            if (mediaSourceId != null && mediaSourceId.isNotEmpty)
              'MediaSourceId': mediaSourceId,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decodedText = utf8.decode(response.bodyBytes);
      throw Exception(_extractErrorMessage(decodedText, response.statusCode));
    }
  }

  Future<void> markPlayed({
    required EmbySettings settings,
    required String itemId,
    bool played = true,
  }) async {
    _ensureAuthorized(settings);
    final uri = _apiUri(settings.serverUrl, [
      'Users',
      settings.userId.trim(),
      'PlayedItems',
      itemId,
    ]);
    final response =
        await (played
                ? _client.post(
                    uri,
                    headers: _authorizedHeaders(settings.accessToken),
                  )
                : _client.delete(
                    uri,
                    headers: _authorizedHeaders(settings.accessToken),
                  ))
            .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decodedText = utf8.decode(response.bodyBytes);
      throw Exception(_extractErrorMessage(decodedText, response.statusCode));
    }
  }

  Future<void> setFavorite({
    required EmbySettings settings,
    required String itemId,
    required bool isFavorite,
  }) async {
    _ensureAuthorized(settings);
    final uri = _apiUri(settings.serverUrl, [
      'Users',
      settings.userId.trim(),
      'FavoriteItems',
      itemId,
    ]);
    final response =
        await (isFavorite
                ? _client.post(
                    uri,
                    headers: _authorizedHeaders(settings.accessToken),
                  )
                : _client.delete(
                    uri,
                    headers: _authorizedHeaders(settings.accessToken),
                  ))
            .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decodedText = utf8.decode(response.bodyBytes);
      throw Exception(_extractErrorMessage(decodedText, response.statusCode));
    }
  }

  Future<List<EmbyVideoItem>> getRecommendations({
    required EmbySettings settings,
    required String itemId,
    int limit = 12,
  }) async {
    _ensureAuthorized(settings);
    final uri = _apiUri(
      settings.serverUrl,
      ['Items', itemId, 'Similar'],
      {
        'UserId': settings.userId.trim(),
        'Limit': limit.toString(),
        'Fields':
            'Overview,SeriesName,ParentIndexNumber,IndexNumber,RunTimeTicks,ProductionYear,CommunityRating,UserData',
      },
    );
    final response = await _client
        .get(uri, headers: _authorizedHeaders(settings.accessToken))
        .timeout(const Duration(seconds: 30));

    final decodedText = utf8.decode(response.bodyBytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(decodedText, response.statusCode));
    }

    final decoded = jsonDecode(decodedText);
    if (decoded is Map<String, dynamic>) {
      final items = decoded['Items'];
      if (items is List) {
        return items
            .whereType<Map<String, dynamic>>()
            .map(_parseVideoItem)
            .where((item) => item.id.isNotEmpty && item.id != itemId)
            .toList(growable: false);
      }
    }
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_parseVideoItem)
          .where((item) => item.id.isNotEmpty && item.id != itemId)
          .toList(growable: false);
    }
    return const [];
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
    final directPlaySupported = _isDirectPlaySupported(mediaSource, container);

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
      playSessionId: playSessionId,
      mediaSourceId: mediaSourceId,
      directPlaySupported: directPlaySupported,
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
      overview: item['Overview']?.toString(),
      communityRating: _asDouble(item['CommunityRating']),
      imageBlurHash: _extractImageBlurHash(item),
      officialRating: item['OfficialRating']?.toString(),
      genres: _asStringList(item['Genres']),
      studios: _parseStudios(item['Studios']),
      people: _parsePeople(item['People']),
      playbackPosition: _runtimeFromTicks(
        _userData(item)?['PlaybackPositionTicks'],
      ),
      playedPercentage: _asDouble(_userData(item)?['PlayedPercentage']),
      isPlayed: _asBool(_userData(item)?['Played']),
      isFavorite: _asBool(_userData(item)?['IsFavorite']),
      playCount: _asInt(_userData(item)?['PlayCount']),
      lastPlayedDate: _asDateTime(_userData(item)?['LastPlayedDate']),
    );
  }

  String? _extractImageBlurHash(Map<String, dynamic> item) {
    final imageTags = item['ImageTags'];
    if (imageTags is Map) {
      return imageTags['Primary']?.toString();
    }
    return null;
  }

  double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
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

  Map<String, String> _jsonAuthorizedHeaders(String token) {
    return {..._authorizedHeaders(token), 'Content-Type': 'application/json'};
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

  Map<String, dynamic>? _userData(Map<String, dynamic> item) {
    final userData = item['UserData'];
    return userData is Map<String, dynamic> ? userData : null;
  }

  List<String> _asStringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _parseStudios(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((entry) {
          if (entry is Map<String, dynamic>) {
            return entry['Name']?.toString().trim() ?? '';
          }
          return entry?.toString().trim() ?? '';
        })
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  List<EmbyPerson> _parsePeople(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (person) => EmbyPerson(
            id: person['Id']?.toString() ?? '',
            name: person['Name']?.toString() ?? '',
            role: person['Role']?.toString(),
            type: person['Type']?.toString(),
            primaryImageTag: person['PrimaryImageTag']?.toString(),
          ),
        )
        .where((person) => person.name.trim().isNotEmpty)
        .toList(growable: false);
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

  /// iOS AVPlayer 原生支持的容器格式。
  static const _directPlayContainers = {
    'mp4',
    'm4v',
    'mov',
    'mp3',
    'm4a',
    'aac',
  };

  /// iOS AVPlayer 原生支持的视频编码。
  static const _directPlayVideoCodecs = {'h264', 'hevc', 'h265', 'mpeg4'};

  /// 判断该媒体源能否被 iOS 原生播放器直接播放。
  ///
  /// 容器或视频编码任一不被支持时返回 false，调用方应直接走 HLS 转码流，
  /// 避免在原生侧等待加载失败再回退。信息缺失时保守地返回 true（仍尝试直连）。
  bool _isDirectPlaySupported(
    Map<String, dynamic>? mediaSource,
    String? container,
  ) {
    if (container != null && !_directPlayContainers.contains(container)) {
      return false;
    }
    final mediaStreams = mediaSource?['MediaStreams'];
    if (mediaStreams is! List) {
      return true;
    }
    for (final stream in mediaStreams) {
      if (stream is! Map<String, dynamic>) {
        continue;
      }
      if (stream['Type']?.toString().toLowerCase() != 'video') {
        continue;
      }
      final codec = stream['Codec']?.toString().toLowerCase();
      if (codec != null &&
          codec.isNotEmpty &&
          !_directPlayVideoCodecs.contains(codec)) {
        return false;
      }
    }
    return true;
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

  int _durationToTicks(Duration duration) {
    return duration.inMicroseconds * 10;
  }

  bool? _asBool(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
    return null;
  }

  DateTime? _asDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
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
