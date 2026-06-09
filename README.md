# 声译 AI

Flutter iOS 应用：应用内视频播放、麦克风实时声音提取、AI 翻译、Liquid Glass 风格悬浮字幕，并预留 iOS Live Activity / 灵动岛原生通道。

## 功能

- 视频听译：选择本地视频或输入网络视频 URL。
- 实时悬浮字幕：字幕窗可在视频画面内拖动、显示/隐藏。
- 后台小窗 / 画中画：iOS 真机支持时，可用系统 PiP 小窗显示识别文本与翻译结果。
- 语音翻译：不播放视频时也可直接用麦克风语音翻译。
- AI 接口：兼容 Chat Completions JSON 格式，可填 OpenAI 或私有网关。
- iOS 能力：已配置麦克风、语音识别、后台音频、Live Activity 开关。

> iOS 普通 App 不能像 Android 一样覆盖到任意第三方 App 上方，也不能直接采集其他 App 音频。本项目走合规方案：应用内悬浮字幕 + 系统 Picture-in-Picture 小窗 + 后台音频配置 + 灵动岛/Live Activity 通道。PiP 需要 iPhone/iPad 真机和系统画中画能力，模拟器/桌面测试环境可能不可用。

## 本地运行

```bash
flutter pub get
flutter run
```

iOS 真机需要在 Xcode 中配置 Apple Developer Team。

## 使用与排错

- 私有网关不需要鉴权时，`API Key` 可以留空；应用不会发送 `Authorization` 请求头。
- 语音识别偶发 `error_no_match` 表示本轮没有听到清晰语音，应用会自动当作可恢复状态处理；视频听译模式会继续监听。
- 如果系统画中画启动失败，主界面字幕和 Live Activity 仍可继续使用。
- 建议真机测试麦克风、语音识别、后台音频、画中画和灵动岛能力。

## GitHub 构建 IPA

已添加 workflow：`.github/workflows/build-ios-ipa.yml`

使用方式：

1. 推送到 GitHub。
2. 打开仓库的 **Actions**。
3. 选择 **Build iOS IPA**。
4. 点击 **Run workflow**。
5. 构建完成后下载 artifact：`ai_voice_translator-unsigned-ipa`。

该 workflow 默认生成 **unsigned IPA**：

```text
build/ios/ipa/ai_voice_translator-unsigned.ipa
```

unsigned IPA 适合后续用 Apple 开发者证书、AltStore、Sideloadly 或自有签名流程重新签名。若要生成可直接 TestFlight/App Store 分发的 IPA，需要在 GitHub Secrets 中配置证书、描述文件，并改用 `flutter build ipa --export-options-plist=...`。
