import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/liquid_glass_theme.dart';
import 'screens/video_library_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置系统 UI 样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
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
      theme: LiquidGlassTheme.darkTheme,
      home: const VideoLibraryScreen(),
    );
  }
}
