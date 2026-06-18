# Phase 2 重构进展

日期：2026-06-18

## 已完成

### iOS 原生播放器基础链路

- 新增 `emby_media_player/native_player` MethodChannel。
- iOS 侧使用 `AVPlayerViewController` 承载播放。
- Dart 侧 `NativePlayerBridge` 支持：
  - initialize
  - play / pause / resume / stop
  - seekTo
  - getCurrentTime / getDuration / isPlaying
  - setPlaybackRate / setVolume
  - getAudioTracks / selectAudioTrack
  - getSubtitleTracks / selectSubtitleTrack
- 播放支持 `startPositionSeconds`，用于断点续播。
- 媒体详情页播放优先 Direct Stream，失败后回退 HLS。
- iOS 侧通过 AVAsset 的 audible / legible media selection group 读取并切换音频/字幕轨道。

### 媒体详情页

- 进入详情页后拉取 Emby 详细信息。
- 展示：
  - 海报和背景图
  - 年份、时长、评分、分级
  - 简介 / 空简介占位
  - 类型标签
  - 制作公司标签
  - 续播进度
  - 演员列表与头像
  - 相关推荐 / 加载骨架 / 空推荐占位 / 失败重试
- 收藏按钮已接入 Emby `FavoriteItems`。
- 新增字幕按钮，可在播放会话存在时读取字幕轨道并切换；支持 `-1` 关闭字幕。
- 播放启动后每 15 秒同步一次原生播放器进度：
  - 读取 `NativePlayerBridge.getCurrentTime()` / `getDuration()` / `isPlaying()`。
  - 调用 `updatePlaybackProgress()` 上报当前位置与暂停状态。
  - 播放超过 90% 后调用 `markPlayed()` 标记已播放。

### EmbyClient 增强

新增接口：

- `fetchMediaDetails()`
- `getResumePoint()`
- `updatePlaybackProgress()`
- `markPlayed()`
- `setFavorite()`
- `getRecommendations()`

解析增强：

- `UserData.PlaybackPositionTicks`
- `UserData.PlayedPercentage`
- `UserData.Played`
- `UserData.IsFavorite`
- `Genres`
- `Studios`
- `People`
- `OfficialRating`

### 清理旧功能

- 移除 Flutter 侧 AI 翻译设置模型与设置页入口。
- 移除旧 Live Activity / 翻译 PiP iOS 源文件与 Xcode 工程引用。
- 更新 iOS 应用名与 Bundle ID：`com.codex.fanyi.embyMediaPlayer`。
- 文档同步到 Emby 媒体播放器定位。

## 验证结果

```bash
flutter analyze
# No issues found

flutter test
# 14/14 passed
```

## 待继续

1. iOS 真机验证：
   - Direct Stream 播放。
   - HLS 回退。
   - 起始时间 seek。
   - 多音轨查询/切换。
   - 字幕轨道查询/切换。
2. 播放会话精细化：
   - 接入 Emby `Sessions/Playing` 开始事件。
   - 携带 `PlaySessionId` 做更完整的播放进度生命周期。
