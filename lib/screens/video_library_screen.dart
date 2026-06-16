import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/liquid_glass_theme.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
import '../settings_store.dart';
import 'video_player_screen.dart';
import 'settings_screen.dart';
import 'emby_browser_screen.dart';

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _settingsStore = SettingsStore();

  EmbySettings _embySettings = EmbySettings.defaults;

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
            const SizedBox(height: LiquidGlassTheme.spaceS),
            Text(
              '连接 Emby 服务器以浏览媒体库',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: LiquidGlassTheme.textTertiary,
                fontSize: 14,
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

    // 已连接 Emby，显示浏览按钮
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: LiquidGlassTheme.glassBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.tv_fill,
              size: 64,
              color: LiquidGlassTheme.accentBlue,
            ),
          ),
          const SizedBox(height: LiquidGlassTheme.spaceL),
          Text(
            'Emby 媒体服务器',
            style: const TextStyle(
              color: LiquidGlassTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: LiquidGlassTheme.spaceS),
          Text(
            '已连接：${_embySettings.username}',
            style: TextStyle(
              color: LiquidGlassTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: LiquidGlassTheme.spaceXl),
          LiquidGlassButton(
            text: '浏览媒体库',
            icon: CupertinoIcons.square_grid_2x2,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmbyBrowserScreen(
                    settings: _embySettings,
                  ),
                ),
              );
            },
            width: 200,
          ),
          const SizedBox(height: LiquidGlassTheme.spaceM),
          LiquidGlassButton(
            text: '重新连接',
            icon: CupertinoIcons.arrow_2_circlepath,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
              _loadEmbySettings();
            },
            backgroundColor: Colors.transparent,
            width: 200,
          ),
        ],
      ),
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
