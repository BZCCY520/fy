# Changelog

所有重要的项目变更都记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [2.0.0] - 2026-06-16

### 🎉 重大更新

这是一个**完全重构**的版本，应用从"声译 AI"转型为"AI 字幕"。

### ✨ 新增

- **Liquid Glass UI 设计系统**
  - 采用 Apple iOS 26 最新 Liquid Glass 设计语言
  - 玻璃材质按钮和卡片组件
  - 流畅的动画效果（300-500ms）
  - 深色模式优化（纯黑背景）

- **新 UI 界面**
  - 视频库界面（Emby/本地/网络三个标签）
  - 沉浸式全屏视频播放界面
  - 全新设置界面（玻璃卡片风格）

- **悬浮字幕组件**
  - 可拖拽调整位置
  - 玻璃背景效果
  - 自适应文本大小

- **视频播放优化**
  - 优先使用 Emby 直接流
  - HLS 流作为自动回退
  - 网络视频 URL 验证（HEAD 请求 + 15s 超时）
  - 详细的错误处理和用户提示

### ❌ 移除

- **语音识别功能**
  - 移除 `speech_to_text` 依赖包
  - 移除麦克风权限
  - 移除语音识别相关 UI

- **语音合成功能**
  - 移除 `flutter_tts` 依赖包
  - 移除 TTS 相关代码

- **Live Activity & PiP**
  - 移除 `live_activity_bridge.dart`
  - 移除 `pip_bridge.dart`
  - 简化后台音频配置

### 🔄 变更

- **应用名称**: "声译 AI" → "AI 字幕"
- **Bundle ID**: `ai_voice_translator` → `ai_subtitle_translator`
- **核心功能**: 语音翻译 → 视频字幕翻译
- **交互方式**: 实时语音 → 手动文本输入

### 🐛 修复

- 修复 Emby 视频无法播放的问题
- 修复视频流优先级导致的兼容性问题
- 修复所有 `withOpacity` 弃用警告
- 修复 BuildContext 跨异步使用警告
- 优化视频控制器初始化检查

### 📝 文档

- 重写 README.md（新增 Liquid Glass 设计说明）
- 新增 REFACTOR_SUMMARY.md（重构详细说明）
- 新增 VIDEO_FIX_SUMMARY.md（视频修复说明）

### 🧪 测试

- 更新所有测试用例
- 更新包名引用（`ai_voice_translator` → `ai_subtitle_translator`）
- **8/8 测试通过**
- **零代码分析警告**

### 📦 依赖

- ❌ 移除 `speech_to_text: ^7.4.0`
- ❌ 移除 `flutter_tts: ^4.2.5`
- ✅ 保留 `http: ^1.6.0`
- ✅ 保留 `shared_preferences: ^2.5.5`
- ✅ 保留 `video_player: ^2.11.1`
- ✅ 保留 `file_picker: ^11.0.2`

### 📊 代码统计

- **新增**: +2095 行
- **删除**: -3842 行
- **净变化**: -1747 行
- **文件变更**: 17 个文件

---

## [1.0.0] - 2024-06-09

### ✨ 初始版本

- 基础应用框架
- 语音识别功能
- AI 翻译功能
- Emby 视频集成
- 实时悬浮字幕
- Live Activity 支持
- Picture-in-Picture 支持

---

## 版本计划

### [2.1.0] - 计划中

**功能增强**：
- [ ] 字幕样式自定义（大小/透明度/颜色）
- [ ] 字幕历史记录查看
- [ ] 字幕导出功能（SRT 格式）
- [ ] 视频缩略图预览
- [ ] 播放列表支持

**UI 优化**：
- [ ] 添加更多 Liquid Glass 组件
- [ ] 优化平板布局
- [ ] 横屏模式优化
- [ ] 手势操作增强

### [2.2.0] - 计划中

**新功能**：
- [ ] 云端语音识别 API 集成
- [ ] 字幕时间轴编辑器
- [ ] 多字幕轨道支持
- [ ] Jellyfin 媒体服务器支持
- [ ] Plex 媒体服务器支持

**性能优化**：
- [ ] 视频预加载优化
- [ ] 内存使用优化
- [ ] 启动速度优化
- [ ] 网络请求优化

### [3.0.0] - 长期计划

**平台扩展**：
- [ ] visionOS 支持
- [ ] macOS 支持
- [ ] watchOS 伴侣应用

**AI 功能**：
- [ ] AI 自动生成字幕
- [ ] 视频内容理解
- [ ] 语音克隆（TTS）
- [ ] 实时翻译优化

**社区功能**：
- [ ] 字幕社区分享
- [ ] 用户评分系统
- [ ] 协作翻译功能

---

## 贡献者

感谢所有为本项目做出贡献的开发者！

- [@BZCCY520](https://github.com/BZCCY520) - 项目创建者和主要维护者

---

## 链接

- [项目主页](https://github.com/BZCCY520/fy)
- [Issues](https://github.com/BZCCY520/fy/issues)
- [Pull Requests](https://github.com/BZCCY520/fy/pulls)
- [Releases](https://github.com/BZCCY520/fy/releases)

---

**注意事项**：

- 版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)：`主版本.次版本.修订号`
- 主版本号：不兼容的 API 修改
- 次版本号：向下兼容的功能性新增
- 修订号：向下兼容的问题修正
