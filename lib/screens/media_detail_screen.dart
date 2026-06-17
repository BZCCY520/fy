import 'dart:ui';
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
  final _embyClient = EmbyClient();
  bool _isPlaying = false;

  Future<void> _playVideo() async {
    if (_isPlaying) return;

    setState(() {
      _isPlaying = true;
    });

    try {
      final source = await _embyClient.getPlaybackSource(
        settings: widget.settings,
        itemId: widget.item.id,
      );

      if (!mounted) return;

      // 使用原生播放器
      await NativePlayerBridge.play(
        url: source.directStreamUri.toString(),
        headers: source.headers,
        enableDolby: true,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开始播放')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backdropUrl = _embyClient.getBackdropUrl(
      serverUrl: widget.settings.serverUrl,
      itemId: widget.item.id,
      width: 1920,
    );

    final posterUrl = _embyClient.getPosterUrl(
      serverUrl: widget.settings.serverUrl,
      itemId: widget.item.id,
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
                _buildInfoSection(),
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
                httpHeaders: {
                  'X-Emby-Token': widget.settings.accessToken,
                },
                placeholder: (context, url) => Container(
                  color: LiquidGlassTheme.surfaceBackground,
                ),
                errorWidget: (context, url, error) => Container(
                  color: LiquidGlassTheme.surfaceBackground,
                ),
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
              httpHeaders: {
                'X-Emby-Token': widget.settings.accessToken,
              },
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
                  widget.item.type == 'Movie'
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
                  widget.item.name,
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
                    if (widget.item.productionYear != null)
                      _buildInfoChip(
                        widget.item.productionYear.toString(),
                        CupertinoIcons.calendar,
                      ),
                    if (widget.item.runtime != null)
                      _buildInfoChip(
                        _formatRuntime(widget.item.runtime!),
                        CupertinoIcons.time,
                      ),
                    if (widget.item.communityRating != null)
                      _buildInfoChip(
                        '⭐ ${widget.item.communityRating!.toStringAsFixed(1)}',
                        null,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.item.type,
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

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LiquidGlassTheme.spaceL),
      child: Row(
        children: [
          Expanded(
            child: LiquidGlassButton(
              text: _isPlaying ? '播放中...' : '播放',
              icon: CupertinoIcons.play_fill,
              onPressed: _isPlaying ? null : _playVideo,
              backgroundColor: LiquidGlassTheme.accentBlue,
              height: 48,
            ),
          ),
          const SizedBox(width: LiquidGlassTheme.spaceM),
          LiquidGlassButton(
            icon: CupertinoIcons.heart,
            onPressed: () {
              // TODO: 收藏功能
            },
            width: 48,
            height: 48,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.all(LiquidGlassTheme.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.item.overview != null && widget.item.overview!.isNotEmpty) ...[
            const Text(
              '简介',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: LiquidGlassTheme.textPrimary,
              ),
            ),
            const SizedBox(height: LiquidGlassTheme.spaceM),
            Text(
              widget.item.overview!,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: LiquidGlassTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
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
