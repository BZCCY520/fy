import 'package:flutter/material.dart';

/// Liquid Glass 设计主题配置
/// 基于 Apple iOS 26 Liquid Glass 设计语言
class LiquidGlassTheme {
  // 颜色系统
  static const Color background = Color(0xFF000000); // 纯黑背景
  static const Color glassBackground = Color(0x33FFFFFF); // 半透明白色玻璃
  static const Color glassBorder = Color(0x1AFFFFFF); // 玻璃边框
  static const Color glassSheen = Color(0x0DFFFFFF); // 玻璃光泽
  static const Color accentBlue = Color(0xFF00A8FF); // 强调色
  static const Color accentPurple = Color(0xFF9D4EDD); // 紫色强调
  static const Color textPrimary = Color(0xFFFFFFFF); // 主文本
  static const Color textSecondary = Color(0x99FFFFFF); // 次要文本
  static const Color textTertiary = Color(0x66FFFFFF); // 第三级文本
  static const Color success = Color(0xFF10B981); // 成功色
  static const Color warning = Color(0xFFFB923C); // 警告色
  static const Color error = Color(0xFFEF4444); // 错误色

  // 圆角
  static const double radiusSmall = 16.0;
  static const double radiusMedium = 24.0;
  static const double radiusLarge = 28.0;
  static const double radiusPill = 999.0;

  // 间距
  static const double spaceXs = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXl = 32.0;
  static const double space2xl = 48.0;

  // 模糊效果
  static const double blurLight = 20.0;
  static const double blurMedium = 30.0;
  static const double blurHeavy = 40.0;

  // 动画
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Curve animationCurve = Curves.easeInOutCubic;

  // 构建主题数据
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'SF Pro Display',
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentPurple,
        surface: Color(0xFF1A1A1A),
        onSurface: textPrimary,
        error: error,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}
