import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/liquid_glass_theme.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
import '../emby_client.dart';
import '../settings_store.dart';
import '../native_player_bridge.dart';

class MediaDetailScreen extends StatefulWidget {
  const MediaDetailScreen({
    super.key,
    required this.item,
    required this.settings,
  });

  final EmbyVideoItem item;
  final EmbySettings settings;

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  static const _progressSyncInterval = Duration(seconds: 15);

  final _embyClient = EmbyClient();
  bool _startingPlayback = false;
  bool _loadingDetails = true;
  bool _loadingRecommendations = true;
  bool _syncingProgress = false;
  bool _reportedPlayed = false;
  Timer? _progressSyncTimer;
  Duration? _lastSyncedPosition;
  bool? _lastSyncedPaused;
  String? _detailsError;
  String? _recommendationsError;
  late EmbyVideoItem _item;
  List<EmbyVideoItem> _recommendations = const [];

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadDetails();
    _loadRecommendations();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loadingDetails = true;
      _detailsError = null;
    });

    try {
      final details = await _embyClient.fetchMediaDetails(
        settings: widget.settings,
        itemId: widget.item.id,
      );
      if (!mounted) return;
      setState(() {
        _item = details;
        _reportedPlayed = details.isPlayed == true;
        _loadingDetails = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _detailsError = error.toString();
        _loadingDetails = false;
      });
    }
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _loadingRecommendations = true;
      _recommendationsError = null;
    });

    try {
      final recommendations = await _embyClient.getRecommendations(
        settings: widget.settings,
        itemId: widget.item.id,
        limit: 8,
      );

      if (!mounted) return;
      setState(() {
        _recommendations = recommendations;
        _loadingRecommendations = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recommendations = const [];
        _recommendationsError = error.toString();
        _loadingRecommendations = false;
      });
    }
  }

  Future<void> _playVideo() async {
    if (_startingPlayback) return;

    setState(() {
      _startingPlayback = true;
    });

    try {
      final source = await _embyClient.getPlaybackSource(
        settings: widget.settings,
        itemId: _item.id,
      );

      if (!mounted) return;

      try {
        await NativePlayerBridge.play(
          url: source.directStreamUri.toString(),
          headers: source.headers,
          enableDolby: true,
          startPositionSeconds: _resumeSeconds,
        );
      } catch (directError) {
        final hlsUri = source.hlsStreamUri;
        if (hlsUri == null) {
          rethrow;
        }
        await NativePlayerBridge.play(
          url: hlsUri.toString(),
          headers: source.headers,
          enableDolby: true,
          startPositionSeconds: _resumeSeconds,
        );
      }

      if (!mounted) return;

      _reportedPlayed = _item.isPlayed == true;
      _startProgressSync();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('开始播放')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('播放失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _startingPlayback = false;
        });
      }
    }
  }

  void _startProgressSync() {
    _progressSyncTimer?.cancel();
    _lastSyncedPosition = null;
    _lastSyncedPaused = null;
    _progressSyncTimer = Timer.periodic(_progressSyncInterval, (_) {
      unawaited(_syncPlaybackProgress());
    });
    unawaited(_syncPlaybackProgress());
  }

  Future<void> _syncPlaybackProgress() async {
    if (_syncingProgress) return;

    _syncingProgress = true;
    try {
      final isPlaying = await NativePlayerBridge.isPlaying();
      final currentSeconds = await NativePlayerBridge.getCurrentTime();
      final durationSeconds = await NativePlayerBridge.getDuration();

      if (!mounted || !currentSeconds.isFinite || currentSeconds <= 0) {
        return;
      }

      final itemId = _item.id;
      final position = _durationFromSeconds(currentSeconds);
      final runtime = durationSeconds.isFinite && durationSeconds > 0
          ? _durationFromSeconds(durationSeconds)
          : _item.runtime;
      final isPaused = !isPlaying;

      if (_lastSyncedPosition == position && _lastSyncedPaused == isPaused) {
        return;
      }

      await _embyClient.updatePlaybackProgress(
        settings: widget.settings,
        itemId: itemId,
        position: position,
        runtime: runtime,
        isPaused: isPaused,
      );

      _lastSyncedPosition = position;
      _lastSyncedPaused = isPaused;

      if (!mounted || _item.id != itemId) return;

      final playedPercentage = _playedPercentage(position, runtime);
      setState(() {
        _item = _item.copyWith(
          playbackPosition: position,
          playedPercentage: playedPercentage,
        );
      });

      if (!_reportedPlayed && _shouldMarkPlayed(position, runtime)) {
        await _embyClient.markPlayed(
          settings: widget.settings,
          itemId: itemId,
          played: true,
        );
        _reportedPlayed = true;

        if (!mounted || _item.id != itemId) return;

        setState(() {
          _item = _item.copyWith(isPlayed: true);
        });
      }
    } catch (error) {
      debugPrint('Failed to sync playback progress: $error');
    } finally {
      _syncingProgress = false;
    }
  }

  Duration _durationFromSeconds(double seconds) {
    return Duration(
      milliseconds: (seconds * Duration.millisecondsPerSecond).round(),
    );
  }

  double? _playedPercentage(Duration position, Duration? runtime) {
    if (runtime == null || runtime.inMilliseconds <= 0) {
      return _item.playedPercentage;
    }
    return (position.inMilliseconds / runtime.inMilliseconds * 100)
        .clamp(0, 100)
        .toDouble();
  }

  bool _shouldMarkPlayed(Duration position, Duration? runtime) {
    if (runtime == null || runtime.inMilliseconds <= 0) {
      return false;
    }
    return position.inMilliseconds / runtime.inMilliseconds >= 0.9;
  }

  @override
  void dispose() {
    _progressSyncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backdropUrl = _embyClient.getBackdropUrl(
      serverUrl: widget.settings.serverUrl,
      itemId: _item.id,
      width: 1920,
    );

    final posterUrl = _embyClient.getPosterUrl(
      serverUrl: widget.settings.serverUrl,
      itemId: _item.id,
      width: 500,
    );

    return Scaffold(
      backgroundColor: LiquidGlassTheme.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(backdropUrl),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(posterUrl),
                _buildActionButtons(),
                if (_loadingDetails) _buildLoadingDetails(),
                if (_detailsError != null) _buildDetailsError(),
                _buildInfoSection(),
                _buildPeopleSection(),
                _buildRecommendationsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(String? backdropUrl) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: LiquidGlassTheme.background,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: LiquidGlassButton(
          icon: CupertinoIcons.back,
          onPressed: () => Navigator.pop(context),
          width: 40,
          height: 40,
          padding: EdgeInsets.zero,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (backdropUrl != null)
              CachedNetworkImage(
                imageUrl: backdropUrl,
                fit: BoxFit.cover,
                httpHeaders: {'X-Emby-Token': widget.settings.accessToken},
                placeholder: (context, url) =>
                    Container(color: LiquidGlassTheme.surfaceBackground),
                errorWidget: (context, url, error) =>
                    Container(color: LiquidGlassTheme.surfaceBackground),
              )
            else
              Container(color: LiquidGlassTheme.surfaceBackground),
            // 渐变遮罩
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    LiquidGlassTheme.background.withValues(alpha: 0.8),
                    LiquidGlassTheme.background,
                  ],
                  stops: const [0.3, 0.7, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(String posterUrl) {
    return Padding(
      padding: const EdgeInsets.all(LiquidGlassTheme.spaceL),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 海报
          ClipRRect(
            borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMedium),
            child: CachedNetworkImage(
              imageUrl: posterUrl,
              width: 120,
              height: 180,
              fit: BoxFit.cover,
              httpHeaders: {'X-Emby-Token': widget.settings.accessToken},
              placeholder: (context, url) => Container(
                width: 120,
                height: 180,
                color: LiquidGlassTheme.glassBackground,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: LiquidGlassTheme.accentBlue,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 120,
                height: 180,
                color: LiquidGlassTheme.glassBackground,
                child: Icon(
                  _item.type == 'Movie'
                      ? CupertinoIcons.film
                      : CupertinoIcons.tv,
                  size: 48,
                  color: LiquidGlassTheme.textTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(width: LiquidGlassTheme.spaceL),
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _item.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: LiquidGlassTheme.textPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (_item.productionYear != null)
                      _buildInfoChip(
                        _item.productionYear.toString(),
                        CupertinoIcons.calendar,
                      ),
                    if (_item.runtime != null)
                      _buildInfoChip(
                        _formatRuntime(_item.runtime!),
                        CupertinoIcons.time,
                      ),
                    if (_item.communityRating != null)
                      _buildInfoChip(
                        '⭐ ${_item.communityRating!.toStringAsFixed(1)}',
                        null,
                      ),
                    if (_item.officialRating != null)
                      _buildInfoChip(_item.officialRating!, null),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _item.type,
                  style: TextStyle(
                    fontSize: 14,
                    color: LiquidGlassTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.glassBackground,
        borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusSmall),
        border: Border.all(color: LiquidGlassTheme.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: LiquidGlassTheme.textSecondary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: LiquidGlassTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: LiquidGlassTheme.textPrimary,
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? message,
    VoidCallback? onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LiquidGlassTheme.spaceM),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.glassBackground,
        borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMedium),
        border: Border.all(color: LiquidGlassTheme.glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: LiquidGlassTheme.textTertiary, size: 22),
          const SizedBox(width: LiquidGlassTheme.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: LiquidGlassTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (message != null && message.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: LiquidGlassTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: LiquidGlassTheme.spaceS),
                  GestureDetector(
                    onTap: onRetry,
                    child: const Text(
                      '重试',
                      style: TextStyle(
                        color: LiquidGlassTheme.accentBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LiquidGlassTheme.spaceL),
      child: Row(
        children: [
          Expanded(
            child: LiquidGlassButton(
              text: _startingPlayback
                  ? '启动中...'
                  : (_item.playbackPosition != null &&
                            _item.playbackPosition! > Duration.zero
                        ? '继续播放'
                        : '播放'),
              icon: CupertinoIcons.play_fill,
              onPressed: _startingPlayback ? null : _playVideo,
              backgroundColor: LiquidGlassTheme.accentBlue,
              height: 48,
            ),
          ),
          const SizedBox(width: LiquidGlassTheme.spaceM),
          LiquidGlassButton(
            icon: _item.isFavorite == true
                ? CupertinoIcons.heart_fill
                : CupertinoIcons.heart,
            onPressed: _toggleFavorite,
            width: 48,
            height: 48,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: LiquidGlassTheme.spaceM),
          LiquidGlassButton(
            icon: Icons.subtitles_rounded,
            onPressed: _showSubtitlePicker,
            width: 48,
            height: 48,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  double? get _resumeSeconds {
    final position = _item.playbackPosition;
    if (position == null || position <= Duration.zero) {
      return null;
    }
    return position.inMilliseconds / 1000;
  }

  Widget _buildInfoSection() {
    final overview = _item.overview?.trim();
    return Padding(
      padding: const EdgeInsets.all(LiquidGlassTheme.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('简介'),
          const SizedBox(height: LiquidGlassTheme.spaceM),
          if (overview != null && overview.isNotEmpty)
            Text(
              overview,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: LiquidGlassTheme.textSecondary,
              ),
            )
          else
            _buildEmptyState(
              icon: CupertinoIcons.text_alignleft,
              title: '暂无简介',
              message: 'Emby 当前没有返回该媒体的剧情简介。',
            ),
          if (_item.genres.isNotEmpty) ...[
            const SizedBox(height: LiquidGlassTheme.spaceL),
            _buildSectionTitle('类型'),
            const SizedBox(height: LiquidGlassTheme.spaceM),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final genre in _item.genres)
                  _buildInfoChip(genre, CupertinoIcons.tag),
              ],
            ),
          ],
          if (_item.studios.isNotEmpty) ...[
            const SizedBox(height: LiquidGlassTheme.spaceL),
            _buildSectionTitle('制作'),
            const SizedBox(height: LiquidGlassTheme.spaceM),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final studio in _item.studios)
                  _buildInfoChip(studio, Icons.business_rounded),
              ],
            ),
          ],
          if (_item.playbackPosition != null &&
              _item.playbackPosition! > Duration.zero) ...[
            const SizedBox(height: LiquidGlassTheme.spaceL),
            _buildResumeProgress(),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingDetails() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: LiquidGlassTheme.spaceM),
      child: Center(
        child: CircularProgressIndicator(
          color: LiquidGlassTheme.accentBlue,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildDetailsError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LiquidGlassTheme.spaceL),
      child: _buildEmptyState(
        icon: CupertinoIcons.exclamationmark_circle,
        title: '详情加载失败',
        message: _detailsError,
        onRetry: _loadDetails,
      ),
    );
  }

  Widget _buildResumeProgress() {
    final runtime = _item.runtime;
    final position = _item.playbackPosition!;
    final progress = runtime == null || runtime.inMilliseconds <= 0
        ? (_item.playedPercentage ?? 0) / 100
        : position.inMilliseconds / runtime.inMilliseconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '续播至 ${_formatRuntime(position)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: LiquidGlassTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusPill),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1).toDouble(),
            minHeight: 6,
            backgroundColor: LiquidGlassTheme.glassBackground,
            color: LiquidGlassTheme.accentBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildPeopleSection() {
    final people = _item.people.take(10).toList(growable: false);
    if (people.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LiquidGlassTheme.spaceL,
        0,
        LiquidGlassTheme.spaceL,
        LiquidGlassTheme.spaceL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('演员'),
          const SizedBox(height: LiquidGlassTheme.spaceM),
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: people.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: LiquidGlassTheme.spaceM),
              itemBuilder: (context, index) {
                final person = people[index];
                return SizedBox(
                  width: 88,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildPersonAvatar(person),
                      const SizedBox(height: LiquidGlassTheme.spaceS),
                      Text(
                        person.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: LiquidGlassTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (person.role != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          person.role!,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: LiquidGlassTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonAvatar(EmbyPerson person) {
    final imageUrl = _personImageUrl(person);
    return ClipOval(
      child: Container(
        width: 64,
        height: 64,
        color: LiquidGlassTheme.glassBackground,
        child: imageUrl == null
            ? _buildPersonAvatarFallback(person)
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                httpHeaders: {'X-Emby-Token': widget.settings.accessToken},
                placeholder: (context, url) =>
                    _buildPersonAvatarFallback(person),
                errorWidget: (context, url, error) =>
                    _buildPersonAvatarFallback(person),
              ),
      ),
    );
  }

  Widget _buildPersonAvatarFallback(EmbyPerson person) {
    final initial = person.name.trim().isEmpty
        ? '?'
        : person.name.trim().characters.first.toUpperCase();
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: LiquidGlassTheme.textSecondary,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
    );
  }

  String? _personImageUrl(EmbyPerson person) {
    if (person.id.trim().isEmpty ||
        person.primaryImageTag == null ||
        person.primaryImageTag!.trim().isEmpty) {
      return null;
    }
    return _embyClient.getImageUrl(
      serverUrl: widget.settings.serverUrl,
      itemId: person.id,
      maxWidth: 160,
      maxHeight: 160,
    );
  }

  Widget _buildRecommendationsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LiquidGlassTheme.spaceL,
        0,
        LiquidGlassTheme.spaceL,
        LiquidGlassTheme.spaceL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('相关推荐'),
          const SizedBox(height: LiquidGlassTheme.spaceM),
          if (_loadingRecommendations)
            _buildRecommendationSkeletonList()
          else if (_recommendationsError != null)
            _buildEmptyState(
              icon: CupertinoIcons.exclamationmark_triangle,
              title: '推荐加载失败',
              message: _recommendationsError,
              onRetry: _loadRecommendations,
            )
          else if (_recommendations.isEmpty)
            _buildEmptyState(
              icon: Icons.video_library_outlined,
              title: '暂无相关推荐',
              message: 'Emby 当前没有为该媒体返回相似内容。',
            )
          else
            _buildRecommendationList(),
        ],
      ),
    );
  }

  Widget _buildRecommendationSkeletonList() {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (context, index) =>
            const SizedBox(width: LiquidGlassTheme.spaceM),
        itemBuilder: (context, index) => const _RecommendationSkeletonCard(),
      ),
    );
  }

  Widget _buildRecommendationList() {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _recommendations.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: LiquidGlassTheme.spaceM),
        itemBuilder: (context, index) {
          final item = _recommendations[index];
          final posterUrl = _embyClient.getPosterUrl(
            serverUrl: widget.settings.serverUrl,
            itemId: item.id,
            width: 220,
          );
          return GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MediaDetailScreen(item: item, settings: widget.settings),
                ),
              );
            },
            child: SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      LiquidGlassTheme.radiusMedium,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: posterUrl,
                      width: 100,
                      height: 150,
                      fit: BoxFit.cover,
                      httpHeaders: {
                        'X-Emby-Token': widget.settings.accessToken,
                      },
                      placeholder: (context, url) =>
                          const _PosterLoadingPlaceholder(width: 100),
                      errorWidget: (context, url, error) =>
                          const _PosterErrorPlaceholder(width: 100),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LiquidGlassTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final nextValue = _item.isFavorite != true;
    final previous = _item;
    setState(() {
      _item = _item.copyWith(isFavorite: nextValue);
    });

    try {
      await _embyClient.setFavorite(
        settings: widget.settings,
        itemId: _item.id,
        isFavorite: nextValue,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _item = previous;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('收藏更新失败：$error')));
    }
  }

  Future<void> _showSubtitlePicker() async {
    final tracks = await NativePlayerBridge.getSubtitleTracks();
    if (!mounted) return;

    if (tracks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前播放器未发现可切换字幕')));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: LiquidGlassTheme.surfaceBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LiquidGlassTheme.radiusLarge),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: LiquidGlassTheme.spaceM,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: LiquidGlassTheme.spaceL,
                    vertical: LiquidGlassTheme.spaceS,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '字幕轨道',
                      style: TextStyle(
                        color: LiquidGlassTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                for (final track in tracks)
                  ListTile(
                    title: Text(
                      _trackTitle(track),
                      style: const TextStyle(
                        color: LiquidGlassTheme.textPrimary,
                      ),
                    ),
                    subtitle: _trackSubtitle(track),
                    trailing: _trackSelected(track)
                        ? const Icon(
                            CupertinoIcons.check_mark,
                            color: LiquidGlassTheme.accentBlue,
                          )
                        : null,
                    onTap: () => _selectSubtitleTrack(context, track),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectSubtitleTrack(
    BuildContext sheetContext,
    Map<String, dynamic> track,
  ) async {
    Navigator.pop(sheetContext);
    final trackIndex = _trackIndex(track);
    await NativePlayerBridge.selectSubtitleTrack(trackIndex);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('字幕已切换：${_trackTitle(track)}')));
  }

  int _trackIndex(Map<String, dynamic> track) {
    final rawIndex = track['index'];
    if (rawIndex is int) {
      return rawIndex;
    }
    if (rawIndex is num) {
      return rawIndex.toInt();
    }
    if (rawIndex is String) {
      return int.tryParse(rawIndex) ?? -1;
    }
    return -1;
  }

  bool _trackSelected(Map<String, dynamic> track) {
    return track['isSelected'] == true;
  }

  String _trackTitle(Map<String, dynamic> track) {
    final displayName = track['displayName'];
    if (displayName is String && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    return track['isOff'] == true ? '关闭字幕' : '字幕 ${_trackIndex(track) + 1}';
  }

  Widget? _trackSubtitle(Map<String, dynamic> track) {
    final languageCode = track['languageCode'];
    if (languageCode is! String || languageCode.trim().isEmpty) {
      return null;
    }
    return Text(
      languageCode.trim(),
      style: TextStyle(color: LiquidGlassTheme.textSecondary),
    );
  }

  String _formatRuntime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours小时$minutes分';
    }
    return '$minutes分钟';
  }
}

class _RecommendationSkeletonCard extends StatelessWidget {
  const _RecommendationSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PosterLoadingPlaceholder(width: 100),
          SizedBox(height: 8),
          _SkeletonLine(width: 88),
          SizedBox(height: 6),
          _SkeletonLine(width: 64),
        ],
      ),
    );
  }
}

class _PosterLoadingPlaceholder extends StatelessWidget {
  const _PosterLoadingPlaceholder({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 150,
      decoration: BoxDecoration(
        color: LiquidGlassTheme.glassBackground,
        borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMedium),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: LiquidGlassTheme.accentBlue,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _PosterErrorPlaceholder extends StatelessWidget {
  const _PosterErrorPlaceholder({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 150,
      decoration: BoxDecoration(
        color: LiquidGlassTheme.glassBackground,
        borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMedium),
      ),
      child: const Icon(
        CupertinoIcons.film,
        color: LiquidGlassTheme.textTertiary,
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: LiquidGlassTheme.glassBorder,
        borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusPill),
      ),
    );
  }
}
