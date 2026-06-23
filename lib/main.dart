import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/liquid_glass_theme.dart';
import 'screens/emby_browser_screen.dart';
import 'screens/settings_screen.dart';
import 'settings_store.dart';
import 'native_player_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NativePlayerBridge.initialize();

  // 设置系统 UI 样式 - 亮色模式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // 强制竖屏
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const EmbyPlayerApp());
}

class EmbyPlayerApp extends StatelessWidget {
  const EmbyPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emby 播放器',
      debugShowCheckedModeBanner: false,
      theme: LiquidGlassTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _settingsStore = SettingsStore();
  EmbySettings _embySettings = EmbySettings.defaults;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsStore.loadEmby();
    if (!mounted) return;
    setState(() {
      _embySettings = settings;
    });
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidGlassTheme.background,
      body: SafeArea(
        child: _embySettings.hasToken
            ? EmbyBrowserScreen(
                settings: _embySettings,
                onOpenSettings: _openSettings,
              )
            : _buildWelcomeScreen(),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_outlined,
              size: 120,
              color: LiquidGlassTheme.accentBlue,
            ),
            const SizedBox(height: 32),
            const Text(
              'Emby 媒体播放器',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: LiquidGlassTheme.textPrimary,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '连接你的 Emby 服务器\n开始畅享影音体验',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: LiquidGlassTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('连接服务器'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LiquidGlassTheme.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
