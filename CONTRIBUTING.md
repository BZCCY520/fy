# 贡献指南

感谢你有兴趣为 Emby 媒体播放器项目做出贡献！

## 如何贡献

### 报告 Bug

提交 Bug 前请先搜索现有 Issues，确认问题是否已被报告。报告中建议包含：

- 清晰的问题标题和描述
- 重现步骤、预期行为和实际行为
- Emby Server 版本、iOS 版本、设备型号、Flutter 版本
- 相关截图、日志或失败的视频格式/编码信息

### 建议新功能

欢迎通过 GitHub Issues 提交功能建议，请说明：

- 功能目标和使用场景
- 可能影响的模块（媒体库、播放器、设置、Emby API 等）
- 是否愿意参与实现或测试

## Pull Request 流程

1. Fork 仓库并创建分支：
   ```bash
   git checkout -b feature/my-new-feature
   ```
2. 开发功能：
   - 遵循现有 Liquid Glass UI 风格
   - 为 Emby API/状态逻辑补充测试
   - 更新 README 或相关文档
3. 验证更改：
   ```bash
   flutter analyze
   flutter test
   ```
4. 提交更改：
   ```bash
   git commit -m "feat: add amazing feature"
   ```

提交信息建议使用：`feat:`、`fix:`、`docs:`、`style:`、`refactor:`、`test:`、`chore:`。

## 开发指南

### 环境设置

```bash
git clone https://github.com/BZCCY520/fy.git
cd fy
flutter pub get
flutter run
```

### 项目结构

```text
lib/
├── main.dart                      # 应用入口
├── emby_client.dart               # Emby API 客户端
├── native_player_bridge.dart      # iOS 原生播放器桥接
├── settings_store.dart            # Emby 设置存储
├── screens/                       # 媒体库、详情、设置页面
├── theme/                         # Liquid Glass 主题
└── widgets/liquid_glass/          # 可复用玻璃组件
```

### 测试示例

```dart
test('fetches video library items with token headers', () async {
  final client = EmbyClient(client: mockClient);
  final videos = await client.fetchVideos(settings: settings);
  expect(videos, isNotEmpty);
});
```

```dart
testWidgets('loads Emby player app', (tester) async {
  await tester.pumpWidget(const EmbyPlayerApp());
  await tester.pumpAndSettle();

  expect(find.text('Emby 媒体播放器'), findsWidgets);
});
```

## 代码规范

- Dart 代码遵循 Effective Dart 和 `flutter_lints`。
- UI 优先复用 `LiquidGlassTheme`、`LiquidGlassCard`、`LiquidGlassButton`。
- Emby 请求需要覆盖成功路径和关键参数断言。
- 原生 iOS 改动应保持 MethodChannel 名称与 Dart 桥接一致。

## 文档

新增或调整功能时，请同步更新：

- `README.md`
- `CHANGELOG.md`
- 相关重构/修复说明文档

## 许可证

通过贡献代码，你同意你的贡献将在 [MIT License](LICENSE) 下发布。

---

再次感谢你的贡献！❤️
