# Changelog

所有重要的项目变更都记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [3.1.0] - 2026-06-21

### ✨ 新增

- **播放会话生命周期（Sessions/Playing）**
  - `EmbyPlaybackSource` 暴露 `playSessionId` 与 `mediaSourceId`。
  - 新增 `reportPlaybackStart()`：播放启动后上报 `Sessions/Playing` 开始事件。
  - 新增 `reportPlaybackStopped()`：离开播放界面时上报 `Sessions/Playing/Stopped`，写入最终续播位置并结束会话。
  - `updatePlaybackProgress()` 携带 `PlaySessionId` 与 `MediaSourceId`，进度上报归属到正确会话。
  - 媒体详情页在播放开始、进度同步、退出三处贯穿同一会话标识，形成完整生命周期。

### 🐛 修复

- **视频无法播放**
  - iOS 原生播放器此前在 `present` 完成回调里立即返回成功，从不观察 `AVPlayerItem.status`，导致媒体加载失败时不抛错、Dart 端 HLS 回退永不触发，用户只见黑屏。
  - 现通过 KVO 观察播放项状态：`readyToPlay` 才返回成功，`failed` 返回错误并收起播放器，叠加 30 秒超时保护。
  - `EmbyPlaybackSource` 新增 `directPlaySupported`，依据容器（mkv/avi 等）与视频编码判断是否可直连；不可直连时直接走 HLS 转码流，避免等待加载失败再回退。

### 🧪 测试

- `flutter analyze`：无问题。
- `flutter test`：16/16 通过。
- 新增 `Sessions/Playing` 开始 / 停止上报单测，覆盖会话标识透传。
- 新增直连兼容性判定单测（mkv/hevc 标记为不可直连）。

---

## [3.0.0] - 2026-06-18

### 🎉 重大更新

项目继续从 AI 字幕工具重构为 **Emby 媒体播放器**，重点转向 Emby 媒体库浏览、媒体详情展示和 iOS 原生播放体验。

### ✨ 新增

- **iOS 原生播放器桥接**
  - 新增 `emby_media_player/native_player` MethodChannel
  - 使用 `AVPlayerViewController` 展示全屏播放
  - 支持暂停、恢复、停止、跳转、播放速度、音量、音轨和字幕轨道查询/切换
  - 支持续播起始时间

- **媒体详情页增强**
  - 加载 Emby 详情数据
  - 展示简介、类型、制作公司、演员头像、推荐内容、续播进度
  - 为简介/推荐增加空状态，为推荐增加加载骨架和失败重试
  - 支持收藏/取消收藏
  - 播放时优先直连，失败后回退 HLS
  - 播放启动后定时同步播放进度，并在超过 90% 后标记已播放
  - 新增字幕轨道切换入口

- **EmbyClient 增强**
  - `fetchMediaDetails()`
  - `getResumePoint()`
  - `updatePlaybackProgress()`
  - `markPlayed()`
  - `setFavorite()`
  - `getRecommendations()`
  - 解析 `UserData`、演员、类型、工作室和评分信息

### 🔄 变更

- 应用名更新为 **Emby 媒体播放器** / **Emby 播放器**。
- Bundle ID 更新为 `com.codex.fanyi.embyMediaPlayer`。
- Emby 客户端标识更新为 `Emby Media Player`。
- 设置页移除 AI 翻译配置，只保留 Emby 服务器连接和应用信息。
- 媒体库请求加入 `UserData` 字段以支持续播进度展示。

### ❌ 移除

- 移除旧 AI 翻译设置模型和存储接口。
- 移除旧 Live Activity / 翻译 PiP 工程引用与源文件。
- 移除旧 `ai_voice_translator` / `ai_subtitle_translator` 运行时通道。

### 🧪 测试

- `flutter analyze`：无问题。
- `flutter test`：14/14 通过。
- 新增 Emby API 单测覆盖详情、进度、收藏、标记已看和推荐接口。
- 新增人物头像图片 URL 构造测试。
- 新增原生播放器桥接单测覆盖字幕轨道读取/选择和音轨结果解析。

---

## [2.0.0] - 2026-06-16

### 🎉 重大更新

项目从早期语音翻译应用重构为视频字幕应用，并引入 Liquid Glass UI、Emby 视频加载优化和字幕相关界面。该版本为后续 3.0.0 转型为 Emby 媒体播放器奠定基础。

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

### [3.2.0] - 计划中

- [ ] 多服务器管理
- [ ] 字幕样式自定义
- [ ] 手势控制（音量、亮度、进度）
- [ ] AirPlay 优化
- [ ] 离线下载
- [ ] 播放列表
- [ ] 深色模式
- [ ] 病毒扫描包（Xcode 15+）

---

## 链接

- [项目主页](https://github.com/BZCCY520/fy)
- [Issues](https://github.com/BZCCY520/fy/issues)
- [Pull Requests](https://github.com/BZCCY520/fy/pulls)
- [Releases](https://github.com/BZCCY520/fy/releases)
