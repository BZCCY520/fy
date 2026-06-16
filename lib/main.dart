import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/liquid_glass_theme.dart';
import 'screens/video_library_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const AISubtitleApp());
}

class AISubtitleApp extends StatelessWidget {
  const AISubtitleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 字幕',
      debugShowCheckedModeBanner: false,
      theme: LiquidGlassTheme.lightTheme,
      home: const VideoLibraryScreen(),
    );
  }
}
