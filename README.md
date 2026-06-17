# Emby 媒体播放器

<div align="center">

![iOS](https://img.shields.io/badge/iOS-26.0+-000000?style=flat&logo=apple)
![Flutter](https://img.shields.io/badge/Flutter-3.11+-02569B?style=flat&logo=flutter)
![License](https://img.shields.io/badge/License-MIT-green)

**专注 Emby 服务器的现代 iOS 媒体播放器**

采用 Apple iOS 26 Liquid Glass 设计语言

[功能特性](#功能特性) • [快速开始](#快速开始) • [使用指南](#使用指南)

</div>

---

## 📱 功能特性

### 媒体播放
- 🎬 **Emby 服务器集成** - 完整的媒体库浏览和管理
- 🎥 **iOS 原生播放器** - AVPlayer，流畅高效
- 🔊 **杜比音频支持** - Dolby Digital/Dolby Atmos
- 📺 **4K/HDR 播放** - 支持高清和 HDR 内容
- 🎯 **多音轨切换** - 支持多语言音轨
- 📝 **字幕支持** - 内嵌和外挂字幕

### 媒体库
- 📚 **分类浏览** - 电影、电视剧、音乐等
- 🔍 **实时搜索** - 快速找到想看的内容
- 🖼️ **海报墙显示** - 精美的视觉呈现
- ⭐ **收藏管理** - 收藏喜欢的内容
- 📊 **观看历史** - 自动记录观看进度
- 🔄 **断点续播** - 从上次位置继续

### 用户体验
- 🪟 **Liquid Glass UI** - iOS 26 最新设计语言
- 🌞 **明亮主题** - 清新优雅的视觉风格
- ✨ **流畅动画** - 精心调校的过渡效果
- 👆 **手势控制** - 音量、亮度、进度调节
- 📱 **画中画模式** - 多任务场景支持

---

## 🚀 快速开始

### 环境要求

- **Flutter**: 3.11.5+
- **Dart**: 3.11.5+
- **iOS**: 26.0+
- **Xcode**: 最新版本
- **Emby Server**: 任意版本

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

---

## 📖 使用指南

### 连接 Emby 服务器

1. 首次打开应用，点击 **连接服务器**
2. 进入设置页面
3. 填写配置：
   - **服务器地址**: `http://192.168.1.100:8096`
   - **用户名**: 你的 Emby 用户名
   - **密码**: 你的密码
4. 点击 **连接** 按钮
5. 连接成功后自动进入媒体库

### 浏览媒体库

1. 主界面自动显示媒体库
2. 切换标签查看不同类型（全部/电影/剧集）
3. 使用搜索框快速查找内容
4. 点击刷新按钮更新媒体库

### 播放视频

1. 点击任意视频卡片
2. 自动开始播放
3. 点击屏幕显示/隐藏控制栏
4. 使用手势控制：
   - 左右滑动：快进/快退
   - 上下滑动（左侧）：调节亮度
   - 上下滑动（右侧）：调节音量

---

## 🎨 设计特色

### Liquid Glass 设计语言

**核心特征**：
- 🪟 半透明玻璃材质
- ✨ 微妙的模糊效果
- 💎 精致的阴影和光泽
- 🌊 流畅的动画过渡

**颜色系统**：
```
背景：#FFFFFF 纯白
玻璃：半透明白色
强调：#007AFF iOS 蓝
文本：黑色渐变
```

---

## 🏗️ 项目结构

```
lib/
├── main.dart                      # 应用入口
├── theme/
│   └── liquid_glass_theme.dart    # Liquid Glass 主题
├── screens/
│   ├── emby_browser_screen.dart   # 媒体库浏览
│   └── settings_screen.dart       # 设置
├── widgets/
│   └── liquid_glass/              # Liquid Glass 组件
├── emby_client.dart               # Emby API 客户端
├── settings_store.dart            # 设置存储
└── native_player_bridge.dart      # 原生播放器桥接
```

---

## 🛠️ 技术栈

- **框架**: Flutter 3.x
- **语言**: Dart 3.11.5+
- **平台**: iOS 26.0+
- **设计**: Liquid Glass (iOS 26)
- **播放器**: AVPlayer (iOS 原生)
- **网络**: http 1.6.0
- **存储**: shared_preferences, sqflite
- **图片**: cached_network_image

---

## 🔧 开发指南

### 代码规范

```bash
# 代码分析
flutter analyze

# 运行测试
flutter test

# 格式化代码
flutter format lib/
```

### 构建 IPA

```bash
# 构建无签名 IPA
flutter build ios --release --no-codesign

# 构建已签名 IPA
flutter build ipa
```

---

## 📝 待实现功能

### 近期计划 (v3.1)
- [ ] 媒体详情页
- [ ] 播放器手势控制
- [ ] 播放进度同步
- [ ] 画中画模式
- [ ] 多服务器管理

### 中期计划 (v3.2)
- [ ] 下载离线观看
- [ ] 播放列表
- [ ] 字幕样式自定义
- [ ] AirPlay 支持
- [ ] 深色模式

### 长期计划 (v4.0)
- [ ] Jellyfin 支持
- [ ] Plex 支持
- [ ] visionOS 支持
- [ ] macOS 支持

---

## 🐛 已知限制

- ⚠️ 仅支持 Emby 服务器
- ⚠️ 需要 iOS 26.0+
- ⚠️ 杜比音频需要真机测试
- ⚠️ 部分功能开发中

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

- Apple 的 Liquid Glass 设计语言
- Emby 团队的优秀媒体服务器
- Flutter 团队的出色框架
- 所有开源贡献者

---

<div align="center">

**⭐ 如果这个项目对你有帮助，请给个 Star！**

Made with ❤️ using Flutter and Liquid Glass

</div>
