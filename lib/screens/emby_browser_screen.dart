import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/liquid_glass_theme.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
import '../widgets/liquid_glass/liquid_glass_card.dart';
import '../emby_client.dart';
import '../settings_store.dart';

class EmbyBrowserScreen extends StatefulWidget {
  const EmbyBrowserScreen({
    super.key,
    required this.settings,
  });

  final EmbySettings settings;

  @override
  State<EmbyBrowserScreen> createState() => _EmbyBrowserScreenState();
}

class _EmbyBrowserScreenState extends State<EmbyBrowserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _embyClient = EmbyClient();
  final _searchController = TextEditingController();

  List<EmbyVideoItem> _allVideos = [];
  List<EmbyVideoItem> _movies = [];
  List<EmbyVideoItem> _episodes = [];
  List<EmbyVideoItem> _searchResults = [];
  bool _loading = true;
  bool _searching = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadVideos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final videos = await _embyClient.fetchVideos(
        settings: widget.settings,
        limit: 100,
      );

      if (!mounted) return;

      setState(() {
        _allVideos = videos;
        _movies = videos.where((v) => v.type == 'Movie').toList();
        _episodes = videos.where((v) => v.type == 'Episode').toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _searchVideos(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _searching = true;
    });

    try {
      final results = await _embyClient.fetchVideos(
        settings: widget.settings,
        searchTerm: query,
        limit: 50,
      );

      if (!mounted) return;
      setState(() {
        _searchResults = results;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('搜索失败：$error')),
      );
    }
  }

  Future<void> _playVideo(EmbyVideoItem item) async {
    try {
      final source = await _embyClient.getPlaybackSource(
        settings: widget.settings,
        itemId: item.id,
      );

      if (!mounted) return;

      // TODO: 实现原生播放器
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('准备播放：${item.displayTitle}\n${source.directStreamUri}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '确定',
            onPressed: () {},
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载视频失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidGlassTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            if (!_searching) _buildTabBar(),
            Expanded(
              child: _searching
                  ? _buildSearchResults()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildVideoGrid(_allVideos),
                        _buildVideoGrid(_movies),
                        _buildVideoGrid(_episodes),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(LiquidGlassTheme.spaceM),
      child: Row(
        children: [
          LiquidGlassButton(
            icon: CupertinoIcons.back,
            onPressed: () => Navigator.pop(context),
            width: 48,
            height: 48,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: LiquidGlassTheme.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emby 媒体库',
                  style: TextStyle(
                    color: LiquidGlassTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                Text(
                  widget.settings.username,
                  style: TextStyle(
                    color: LiquidGlassTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          LiquidGlassButton(
            icon: CupertinoIcons.refresh,
            onPressed: _loadVideos,
            width: 48,
            height: 48,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LiquidGlassTheme.spaceM,
        vertical: LiquidGlassTheme.spaceS,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMedium),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: LiquidGlassTheme.blurMedium,
            sigmaY: LiquidGlassTheme.blurMedium,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: LiquidGlassTheme.glassBackground,
              borderRadius:
                  BorderRadius.circular(LiquidGlassTheme.radiusMedium),
              border: Border.all(color: LiquidGlassTheme.glassBorder),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.search,
                  color: LiquidGlassTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                      color: LiquidGlassTheme.textPrimary,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: '搜索电影、剧集...',
                      hintStyle: TextStyle(
                        color: LiquidGlassTheme.textTertiary,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: _searchVideos,
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      CupertinoIcons.clear_circled_solid,
                      color: LiquidGlassTheme.textSecondary,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searching = false;
                        _searchResults = [];
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: LiquidGlassTheme.spaceM,
        vertical: LiquidGlassTheme.spaceS,
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: LiquidGlassTheme.glassBackground,
          borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMedium),
        ),
        dividerColor: Colors.transparent,
        labelColor: LiquidGlassTheme.textPrimary,
        unselectedLabelColor: LiquidGlassTheme.textSecondary,
        tabs: [
          Tab(text: '全部 (${_allVideos.length})'),
          Tab(text: '电影 (${_movies.length})'),
          Tab(text: '剧集 (${_episodes.length})'),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 64,
              color: LiquidGlassTheme.textTertiary,
            ),
            const SizedBox(height: LiquidGlassTheme.spaceM),
            Text(
              '没有找到匹配的内容',
              style: TextStyle(
                color: LiquidGlassTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return _buildVideoGrid(_searchResults);
  }

  Widget _buildVideoGrid(List<EmbyVideoItem> videos) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: LiquidGlassTheme.accentBlue,
        ),
      );
    }

    if (_errorText != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(LiquidGlassTheme.spaceL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 64,
                color: LiquidGlassTheme.error,
              ),
              const SizedBox(height: LiquidGlassTheme.spaceM),
              Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LiquidGlassTheme.textSecondary,
                ),
              ),
              const SizedBox(height: LiquidGlassTheme.spaceL),
              LiquidGlassButton(
                text: '重试',
                icon: CupertinoIcons.refresh,
                onPressed: _loadVideos,
              ),
            ],
          ),
        ),
      );
    }

    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.film,
              size: 64,
              color: LiquidGlassTheme.textTertiary,
            ),
            const SizedBox(height: LiquidGlassTheme.spaceM),
            Text(
              '暂无视频',
              style: TextStyle(
                color: LiquidGlassTheme.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(LiquidGlassTheme.spaceM),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: LiquidGlassTheme.spaceM,
        mainAxisSpacing: LiquidGlassTheme.spaceM,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return _buildVideoCard(video);
      },
    );
  }

  Widget _buildVideoCard(EmbyVideoItem video) {
    final posterUrl = _embyClient.getPosterUrl(
      serverUrl: widget.settings.serverUrl,
      itemId: video.id,
      width: 300,
    );

    return LiquidGlassCard(
      padding: EdgeInsets.zero,
      onTap: () => _playVideo(video),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 海报图片
          AspectRatio(
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(LiquidGlassTheme.radiusLarge),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover,
                    httpHeaders: {
                      'X-Emby-Token': widget.settings.accessToken,
                    },
                    placeholder: (context, url) => Container(
                      color: LiquidGlassTheme.glassBackground,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: LiquidGlassTheme.accentBlue,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: LiquidGlassTheme.glassBackground,
                      child: Center(
                        child: Icon(
                          video.type == 'Movie'
                              ? CupertinoIcons.film
                              : CupertinoIcons.tv,
                          size: 48,
                          color: LiquidGlassTheme.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  // 播放按钮叠加层
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.play_fill,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 信息
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LiquidGlassTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (video.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      video.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: LiquidGlassTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (video.communityRating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.star_fill,
                          size: 12,
                          color: LiquidGlassTheme.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          video.communityRating!.toStringAsFixed(1),
                          style: TextStyle(
                            color: LiquidGlassTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
