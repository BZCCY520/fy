# 视频播放问题修复总结

## 问题诊断

视频无法播放的主要原因：

1. **HLS 流优先级过高**：原代码优先使用 HLS (HTTP Live Streaming) 流，但 Flutter 的 video_player 插件在某些平台上对 HLS 的支持不够稳定
2. **缺少错误回退机制**：视频加载失败后没有尝试备用方案
3. **网络视频 URL 验证不足**：直接加载网络视频 URL 可能导致长时间等待或静默失败
4. **错误信息不够详细**：视频加载失败时缺少具体的错误描述

## 修复内容

### 1. 优化 Emby 视频加载策略 (`lib/main.dart`)

**变更**：优先使用直接流 (Direct Stream)，失败后自动回退到 HLS 流

```dart
// 修复前：优先 HLS
final uri = source.hlsStreamUri ?? source.directStreamUri;

// 修复后：优先直接流，带回退机制
var uri = source.directStreamUri;
try {
  await _loadVideoController(...); // 尝试直接流
  return;
} catch (directError) {
  if (source.hlsStreamUri != null) {
    await _loadVideoController(...); // 回退到 HLS
  }
}
```

**好处**：
- 直接流兼容性更好，延迟更低
- 失败时自动尝试 HLS，提高成功率
- 详细记录两种方式的失败信息

### 2. 增强视频控制器初始化 (`lib/main.dart`)

**新增功能**：
- 检查控制器是否成功初始化
- 检查视频源是否有错误
- 提供详细的错误描述
- 失败时重新抛出异常供上层处理

```dart
if (!controller.value.isInitialized) {
  throw Exception('视频控制器初始化失败：未能初始化视频源');
}
if (controller.value.hasError) {
  throw Exception('视频控制器错误：${controller.value.errorDescription}');
}
```

### 3. 改进网络视频 URL 验证 (`lib/main.dart`)

**新增功能**：
- 加载前发送 HEAD 请求验证 URL 可访问性
- 15 秒超时机制避免长时间挂起
- 检查 HTTP 状态码（4xx/5xx 错误提前拦截）
- 提供清晰的验证失败提示

```dart
final headResponse = await timeoutClient
    .head(uri)
    .timeout(const Duration(seconds: 15));
if (headResponse.statusCode < 200 || headResponse.statusCode >= 400) {
  throw Exception('视频源返回 ${headResponse.statusCode} 错误');
}
```

### 4. 优化 Emby 播放源请求 (`lib/emby_client.dart`)

**改进**：
- 在 HTTP headers 中添加 `Accept: */*`，提高服务器兼容性
- 优化直接流 URL 构建逻辑
- 增强注释说明 HLS 作为备用方案的原因

```dart
headers: {
  'X-Emby-Token': token,
  'X-MediaBrowser-Token': token,
  'Accept': '*/*', // 新增
},
```

### 5. 更新 iOS 网络权限配置 (`ios/Runner/Info.plist`)

**新增配置**：
```xml
<key>NSAllowsArbitraryLoads</key>
<true/>
<key>NSAllowsArbitraryLoadsInWebContent</key>
<true/>
```

**好处**：
- 允许加载 HTTP 和 HTTPS 视频源
- 支持本地网络和公网视频
- 满足 Emby 服务器和网络视频的各种场景

## 测试建议

### 1. Emby 视频测试
- [ ] 测试 Emby 服务器视频播放（直接流）
- [ ] 测试需要转码的视频（HLS 流）
- [ ] 测试不同格式视频（MP4、MKV、AVI 等）
- [ ] 测试局域网和公网 Emby 服务器

### 2. 网络视频测试
- [ ] 测试公开 HTTPS 视频 URL
- [ ] 测试 HTTP 视频 URL（需要 iOS 权限）
- [ ] 测试无效 URL 的错误提示
- [ ] 测试超时场景

### 3. 本地视频测试
- [ ] 测试从相册选择视频
- [ ] 测试大文件视频（>1GB）
- [ ] 测试各种编码格式

### 4. 错误场景测试
- [ ] 网络断开时的错误提示
- [ ] 视频格式不支持的错误提示
- [ ] Emby 服务器连接失败的提示
- [ ] 播放权限不足的提示

## 使用注意事项

1. **iOS 真机测试**：某些视频格式和网络配置只能在真机上测试，模拟器可能表现不同
2. **网络环境**：确保设备能访问 Emby 服务器或视频 URL
3. **视频格式**：推荐使用 H.264 编码的 MP4 格式以获得最佳兼容性
4. **Emby 配置**：确保 Emby 服务器允许直接播放（无需强制转码）

## 已知限制

1. **HLS 兼容性**：某些 HLS 流在 Android 上可能表现不同
2. **视频编解码器**：设备不支持的编解码器需要 Emby 服务器端转码
3. **网络延迟**：网络视频预加载时间取决于网络速度

## 后续优化建议

1. 添加视频预加载进度显示
2. 支持视频播放速度调节
3. 添加视频缓存机制
4. 支持字幕文件加载（独立于听译功能）
5. 优化视频播放内存占用
