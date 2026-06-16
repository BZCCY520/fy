# AI 字幕 - Liquid Glass 视频字幕翻译应用

<div align="center">

![iOS](https://img.shields.io/badge/iOS-26.0+-000000?style=flat&logo=apple)
![Flutter](https://img.shields.io/badge/Flutter-3.11+-02569B?style=flat&logo=flutter)
![License](https://img.shields.io/badge/License-MIT-green)
![Build](https://img.shields.io/github/actions/workflow/status/BZCCY520/fy/build-ios-ipa.yml?label=Build)

**专注视频播放和 AI 字幕翻译的现代 iOS 应用**

采用 Apple iOS 26 最新 Liquid Glass 设计语言

[功能特性](#功能特性) • [快速开始](#快速开始) • [使用指南](#使用指南) • [设计系统](#设计系统)

</div>

---

## 📱 功能特性

### 视频播放
- 🎬 **Emby 媒体库集成** - 浏览和播放 Emby 服务器视频
- 📁 **本地视频支持** - 从相册或文件管理器选择视频
- 🌐 **网络视频播放** - 支持 HTTPS/HTTP 视频 URL
- 🎥 **沉浸式播放** - 全屏播放，自动隐藏控制栏

### AI 字幕翻译
- 🤖 **AI 驱动翻译** - 支持 OpenAI 和兼容 API
- 🌍 **11 种语言** - 中文、英语、日语、韩语等
- 💬 **悬浮字幕** - 可拖拽调整位置的半透明字幕
- 📝 **手动输入** - 支持粘贴文本进行翻译

### 设计与体验
- 🪟 **Liquid Glass UI** - iOS 26 最新设计语言
- 🌓 **深色模式** - 优雅的纯黑背景
- ✨ **流畅动画** - 300-500ms 精心调校的过渡效果
- 🎨 **玻璃材质** - 模糊背景、微妙渐变和光泽效果

---

## 🚀 快速开始

### 环境要求

- **Flutter**: 3.11.5+
- **Dart**: 3.11.5+
- **iOS**: 26.0+
- **Xcode**: 最新版本
- **macOS**: 用于 iOS 开发

### 安装步骤

```bash
# 1. 克隆仓库
git clone https://github.com/BZCCY520/fy.git
cd fy

# 2. 安装依赖
flutter pub get

# 3. 运行应用
flutter run
```

### iOS 真机运行

1. 在 Xcode 中打开 `ios/Runner.xcworkspace`
2. 配置你的 Apple Developer Team
3. 连接 iOS 设备
4. 运行 `flutter run -d <device-id>`

---

## 📖 使用指南

### 配置 AI 翻译

1. 点击右上角 ⚙️ **设置**
2. 进入 **AI 翻译** 卡片
3. 填写配置：
   - **Endpoint**: `https://api.openai.com/v1/chat/completions`
   - **API Key**: 你的 OpenAI API Key
   - **Model**: `gpt-4.1-mini` 或其他模型
4. 点击 **保存**

### 连接 Emby 服务器

1. 在设置中找到 **Emby 媒体服务器**
2. 点击 **连接**
3. 输入：
   - 服务器地址：`http://192.168.1.100:8096`
   - 用户名和密码
4. 连接成功后即可浏览媒体库

### 播放视频并翻译

#### 方式一：Emby 视频
1. 切换到 **Emby** 标签
2. 从列表中选择视频
3. 点击播放

#### 方式二：本地视频
1. 切换到 **本地** 标签
2. 点击 **选择视频**
3. 从文件管理器选择

#### 方式三：网络视频
1. 切换到 **网络** 标签
2. 点击 **输入 URL**
3. 粘贴视频链接

### 添加字幕

1. 播放视频时点击底部 **字幕** 按钮
2. 输入或粘贴要翻译的文本
3. 选择源语言和目标语言
4. 点击 **开始翻译**
5. 字幕将悬浮显示，可拖拽调整位置

---

## 🎨 设计系统

### Liquid Glass 特性

本应用完整实现了 Apple iOS 26 的 Liquid Glass 设计语言：

**核心特征**：
- 🪟 **玻璃材质** - 半透明白色背景 + 模糊效果
- ✨ **悬浮控件** - 按钮和卡片浮于内容之上
- 💊 **胶囊形状** - 插入式标签栏，圆角 999px
- 🌊 **流体动画** - 微妙的缩放和淡入淡出

**颜色系统**：
```
背景：#000000 纯黑
玻璃：#33FFFFFF 半透明白
强调：#00A8FF 蓝色
文本：#FFFFFF / #99FFFFFF
```

**组件库**：
- `LiquidGlassButton` - 玻璃按钮
- `LiquidGlassCard` - 玻璃卡片  
- `FloatingSubtitle` - 悬浮字幕

---

## 🏗️ 项目结构

```
lib/
├── main.dart                    # 应用入口
├── theme/
│   └── liquid_glass_theme.dart  # Liquid Glass 主题
├── screens/
│   ├── video_library_screen.dart   # 视频库
│   ├── video_player_screen.dart    # 播放界面
│   └── settings_screen.dart        # 设置
├── widgets/
│   ├── liquid_glass/
│   │   ├── liquid_glass_button.dart
│   │   └── liquid_glass_card.dart
│   └── subtitle/
│       └── floating_subtitle.dart
├── ai_translator.dart           # AI 翻译逻辑
├── emby_client.dart            # Emby 客户端
├── language_option.dart        # 语言选项
└── settings_store.dart         # 设置存储
```

---

## 🛠️ 技术栈

- **框架**: Flutter 3.x
- **语言**: Dart 3.11.5+
- **平台**: iOS 26.0+
- **设计**: Liquid Glass (iOS 26)
- **视频**: video_player 2.11.1
- **网络**: http 1.6.0
- **存储**: shared_preferences 2.5.5

---

## 🔧 GitHub Actions 构建

项目包含自动化 CI/CD 工作流：

### 构建 IPA

1. 打开仓库的 **Actions** 标签
2. 选择 **Build unsigned IPA** 工作流
3. 点击 **Run workflow**
4. 等待构建完成
5. 下载 artifact：`ai_subtitle_translator-unsigned-ipa`

生成的是 **unsigned IPA**，适合使用以下工具重新签名：
- AltStore
- Sideloadly  
- 自有签名流程

---

## 📝 开发指南

### 代码规范

```bash
# 代码分析
flutter analyze

# 运行测试
flutter test

# 格式化代码
flutter format lib/
```

### 添加新组件

所有 Liquid Glass 组件应放在 `lib/widgets/liquid_glass/` 目录：

```dart
import '../../theme/liquid_glass_theme.dart';

class LiquidGlassExample extends StatelessWidget {
  // 使用 LiquidGlassTheme 中的颜色和尺寸常量
  // 遵循玻璃材质效果设计
}
```

---

## 🐛 已知限制

- ❌ 不支持实时语音识别（已移除）
- ❌ 需手动输入字幕文本
- ⚠️ 需配置第三方 AI 翻译 API
- ⚠️ UI 主要针对 iOS 优化

---

## 📅 更新日志

查看 [CHANGELOG.md](CHANGELOG.md) 了解详细版本历史。

### v2.0.0 (2026-06-16)

**重大更新**：
- ✨ 全面重构为视频字幕翻译应用
- 🎨 采用 iOS 26 Liquid Glass 设计
- ❌ 移除语音识别功能
- 🪟 全新 UI 组件库
- 📱 沉浸式视频播放体验

---

## 🤝 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing`)
5. 开启 Pull Request

**代码要求**：
- 遵循 Liquid Glass 设计规范
- 通过 `flutter analyze` 检查
- 包含必要的测试
- 添加清晰的注释

---

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 💬 联系方式

- **GitHub**: [@BZCCY520](https://github.com/BZCCY520)
- **Issues**: [报告问题](https://github.com/BZCCY520/fy/issues)

---

## 🙏 致谢

- Apple 设计团队的 Liquid Glass 设计语言
- Flutter 团队的优秀框架
- 所有开源贡献者

---

<div align="center">

**⭐ 如果这个项目对你有帮助，请给个 Star！**

Made with ❤️ using Flutter and Liquid Glass

</div>
