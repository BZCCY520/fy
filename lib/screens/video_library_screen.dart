import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/liquid_glass_theme.dart';
import '../widgets/liquid_glass/liquid_glass_card.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
import '../emby_client.dart';
import '../settings_store.dart';
import 'video_player_screen.dart';
import 'settings_screen.dart';

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _embyClient = EmbyClient();
  final _settingsStore = SettingsStore();

  EmbySettings _embySettings = EmbySettings.defaults;
  List<EmbyVideoItem> _embyVideos = [];
  bool _embyLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadEmbySettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEmbySettings() async {
    final settings = await _settingsStore.loadEmby();
    if (!mounted) return;
    setState(() {
      _embySettings = settings;
    });
    if (settings.hasToken) {
      _loadEmbyVideos();
    }
  }

  Future<void> _loadEmbyVideos() async {
    if (!_embySettings.hasToken) return;

    setState(() {
      _embyLoading = true;
      _errorText = null;
    });

    try {
      final videos = await _embyClient.fetchVideos(
        settings: _embySettings,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _embyVideos = videos;
        _embyLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _embyLoading = false;
        _errorText = error.toString();
      });
    }
  }

  Future<void> _pickLocalVideo() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    final path = result?.files.single.path;
    if (path == null || path.isEmpty || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoFile: File(path),
          title: result!.files.single.name,
        ),
      ),
    );
  }

  Future<void> _openNetworkVideoDialog() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LiquidGlassTheme.background,
        title: const Text('输入视频 URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/video.mp4',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (url == null || url.trim().isEmpty || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoUrl: url.trim(),
          title: Uri.tryParse(url)?.host ?? 'Network Video',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidGlassTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEmbyTab(),
                  _buildLocalTab(),
                  _buildNetworkTab(),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      LiquidGlassTheme.textPrimary,
                      LiquidGlassTheme.accentBlue,
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'AI 字幕',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Liquid Glass · iOS 26',
                  style: TextStyle(
                    color: LiquidGlassTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          LiquidGlassButton(
            icon: CupertinoIcons.settings,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
              _loadEmbySettings();
            },
            width: 48,
            height: 48,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: LiquidGlassTheme.spaceM),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: LiquidGlassTheme.glassBackground,
          borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMedium),
        ),
        dividerColor: Colors.transparent,
        labelColor: LiquidGlassTheme.textPrimary,
        unselectedLabelColor: LiquidGlassTheme.textSecondary,
        tabs: const [
          Tab(text: 'Emby'),
          Tab(text: '本地'),
          Tab(text: '网络'),
        ],
      ),
    );
  }

  Widget _buildEmbyTab() {
    if (!_embySettings.hasToken) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.tv,
              size: 64,
              color: LiquidGlassTheme.textTertiary,
            ),
            const SizedBox(height: LiquidGlassTheme.spaceM),
            Text(
              '未连接 Emby',
              style: TextStyle(
                color: LiquidGlassTheme.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: LiquidGlassTheme.spaceL),
            LiquidGlassButton(
              text: '去设置',
              icon: CupertinoIcons.settings,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
                _loadEmbySettings();
              },
            ),
          ],
        ),
      );
    }

    if (_embyLoading) {
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
                onPressed: _loadEmbyVideos,
              ),
            ],
          ),
        ),
      );
    }

    if (_embyVideos.isEmpty) {
      return Center(
        child: Text(
          '没有找到视频',
          style: TextStyle(
            color: LiquidGlassTheme.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(LiquidGlassTheme.spaceM),
      itemCount: _embyVideos.length,
      itemBuilder: (context, index) {
        final video = _embyVideos[index];
        return LiquidGlassCard(
          margin: const EdgeInsets.only(bottom: LiquidGlassTheme.spaceM),
          onTap: () {
            // TODO: Load Emby video
          },
          child: Row(
            children: [
              Container(
                width: 100,
                height: 60,
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.glassSheen,
                  borderRadius:
                      BorderRadius.circular(LiquidGlassTheme.radiusSmall),
                ),
                child: const Icon(
                  CupertinoIcons.play_rectangle_fill,
                  color: LiquidGlassTheme.textSecondary,
                ),
              ),
              const SizedBox(width: LiquidGlassTheme.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LiquidGlassTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (video.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        video.subtitle,
                        style: TextStyle(
                          color: LiquidGlassTheme.textTertiary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocalTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.folder,
            size: 64,
            color: LiquidGlassTheme.textTertiary,
          ),
          const SizedBox(height: LiquidGlassTheme.spaceM),
          Text(
            '选择本地视频文件',
            style: TextStyle(
              color: LiquidGlassTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: LiquidGlassTheme.spaceL),
          LiquidGlassButton(
            text: '选择视频',
            icon: CupertinoIcons.folder_open,
            onPressed: _pickLocalVideo,
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.link,
            size: 64,
            color: LiquidGlassTheme.textTertiary,
          ),
          const SizedBox(height: LiquidGlassTheme.spaceM),
          Text(
            '输入网络视频 URL',
            style: TextStyle(
              color: LiquidGlassTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: LiquidGlassTheme.spaceL),
          LiquidGlassButton(
            text: '输入 URL',
            icon: CupertinoIcons.link,
            onPressed: _openNetworkVideoDialog,
          ),
        ],
      ),
    );
  }
}
