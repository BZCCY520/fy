# iOS + Flutter 开发环境配置指南

本文档帮助你在新电脑上配置完整的 iOS 和 Flutter 开发环境。

---

## 📋 系统要求

### 硬件要求
- **Mac 电脑**（必须，iOS 开发只能在 macOS 上进行）
- **最低配置**：
  - macOS 13.0 (Ventura) 或更高
  - 8GB RAM（推荐 16GB+）
  - 50GB+ 可用空间
  - Intel 或 Apple Silicon (M1/M2/M3)

---

## 🛠️ 必装软件清单

### 1. Xcode（必须）

**下载方式一：App Store**
1. 打开 Mac App Store
2. 搜索 "Xcode"
3. 点击"获取"并安装（约 12-15GB）

**下载方式二：Apple Developer**
- 访问：https://developer.apple.com/download/
- 下载最新 Xcode（需要 Apple ID）

**安装后配置**：
```bash
# 1. 安装命令行工具
sudo xcode-select --install

# 2. 接受许可协议
sudo xcodebuild -license accept

# 3. 验证安装
xcode-select -p
# 应该输出：/Applications/Xcode.app/Contents/Developer
```

**Xcode 版本要求**：
- iOS 26.0 开发：需要 Xcode 16.0+
- 建议：始终使用最新稳定版

---

### 2. Homebrew（包管理器，推荐）

```bash
# 安装 Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Apple Silicon Mac 需要配置环境变量
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# 验证安装
brew --version
```

---

### 3. Flutter SDK（必须）

**方式一：使用 Homebrew（推荐）**
```bash
# 安装 Flutter
brew install --cask flutter

# 验证安装
flutter --version
```

**方式二：手动安装**
```bash
# 1. 下载 Flutter SDK
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable

# 2. 配置环境变量（添加到 ~/.zshrc 或 ~/.bash_profile）
export PATH="$PATH:$HOME/development/flutter/bin"

# 3. 刷新环境变量
source ~/.zshrc

# 4. 验证安装
flutter --version
```

**配置 Flutter**：
```bash
# 运行诊断
flutter doctor

# 下载依赖
flutter precache

# 安装 iOS 工具链
flutter doctor --android-licenses  # Android 相关
flutter config --enable-ios  # 启用 iOS
```

---

### 4. CocoaPods（iOS 依赖管理，必须）

```bash
# 方式一：使用 Homebrew（推荐）
brew install cocoapods

# 方式二：使用 gem
sudo gem install cocoapods

# 验证安装
pod --version

# 设置 CocoaPods
pod setup
```

---

### 5. Git（版本控制）

```bash
# 检查是否已安装
git --version

# 如未安装，使用 Homebrew 安装
brew install git

# 配置 Git
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"

# 配置 GitHub SSH（可选但推荐）
ssh-keygen -t ed25519 -C "你的邮箱"
# 按提示完成，然后添加到 GitHub
cat ~/.ssh/id_ed25519.pub
# 复制输出，添加到 GitHub Settings > SSH Keys
```

---

## 🔧 开发工具（推荐）

### 1. VS Code（代码编辑器）

```bash
# 使用 Homebrew 安装
brew install --cask visual-studio-code

# 安装 Flutter 插件
# 打开 VS Code，安装以下扩展：
# - Flutter
# - Dart
# - iOS Debug (Webkit)
```

### 2. Android Studio（可选，用于 Android 开发）

```bash
# 使用 Homebrew 安装
brew install --cask android-studio

# 安装后需要：
# 1. 打开 Android Studio
# 2. 安装 Android SDK
# 3. 安装 Flutter 和 Dart 插件
```

---

## 📱 iOS 开发配置

### 1. Apple Developer 账号

**免费账号**：
- 可以真机调试
- 每 7 天需重新签名
- 无法发布到 App Store

**付费账号（$99/年）**：
- 完整开发权限
- 可发布到 App Store
- 证书和描述文件管理

**注册地址**：https://developer.apple.com/

### 2. 配置 Xcode 开发者账号

1. 打开 Xcode
2. 菜单：**Xcode > Settings (Preferences)**
3. 选择 **Accounts** 标签
4. 点击 **+** 添加 Apple ID
5. 登录你的 Apple 开发者账号

### 3. 配置真机调试

**连接 iPhone/iPad**：
```bash
# 1. 用数据线连接设备
# 2. 在设备上信任电脑
# 3. 在 Xcode 中选择设备

# 查看已连接设备
flutter devices
```

**配置代码签名**：
1. 在 Xcode 中打开项目：`ios/Runner.xcworkspace`
2. 选择 **Runner** target
3. 选择 **Signing & Capabilities**
4. 勾选 **Automatically manage signing**
5. 选择你的 **Team**

---

## 🚀 项目配置

### 克隆本项目

```bash
# 1. 克隆仓库
git clone https://github.com/BZCCY520/fy.git
cd fy

# 2. 安装 Flutter 依赖
flutter pub get

# 3. 安装 iOS 依赖
cd ios
pod install
cd ..

# 4. 运行项目
flutter run -d <device-id>
```

### 常见问题修复

**问题 1：CocoaPods 安装慢**
```bash
# 使用国内镜像
cd ~/.cocoapods/repos
pod repo remove master
git clone https://mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs.git master
pod setup
```

**问题 2：Flutter 下载慢**
```bash
# 配置 Flutter 镜像（中国大陆）
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# 添加到 ~/.zshrc 永久生效
echo 'export PUB_HOSTED_URL=https://pub.flutter-io.cn' >> ~/.zshrc
echo 'export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn' >> ~/.zshrc
```

**问题 3：Xcode 构建失败**
```bash
# 清理并重新构建
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter pub get
flutter build ios
```

---

## ✅ 验证环境

运行以下命令检查环境配置：

```bash
# 1. Flutter 诊断
flutter doctor -v

# 期望输出（全部打钩）：
# ✓ Flutter (Channel stable, x.x.x)
# ✓ Xcode - develop for iOS
# ✓ VS Code
# ✓ Connected device
```

**完整检查清单**：
```bash
# 检查 Xcode
xcodebuild -version

# 检查 Flutter
flutter --version

# 检查 Dart
dart --version

# 检查 CocoaPods
pod --version

# 检查 Git
git --version

# 检查设备连接
flutter devices
```

---

## 📦 可选工具

### 性能优化工具

```bash
# Fastlane（自动化构建）
brew install fastlane

# SwiftLint（Swift 代码规范）
brew install swiftlint

# xcpretty（美化 Xcode 输出）
brew install xcpretty
```

### 实用工具

```bash
# SourceTree（Git GUI）
brew install --cask sourcetree

# Charles（抓包工具）
brew install --cask charles

# Postman（API 测试）
brew install --cask postman

# ImageOptim（图片优化）
brew install --cask imageoptim
```

---

## 🎯 开发流程

### 日常开发

```bash
# 1. 启动模拟器
open -a Simulator

# 2. 运行项目
flutter run

# 3. 热重载
# 在终端按 r

# 4. 重启应用
# 在终端按 R
```

### 真机测试

```bash
# 1. 连接设备
flutter devices

# 2. 指定设备运行
flutter run -d <device-id>

# 3. Release 模式
flutter run --release
```

### 构建 IPA

```bash
# 1. 构建（无签名）
flutter build ios --release --no-codesign

# 2. 构建（有签名）
flutter build ipa

# 3. IPA 位置
# build/ios/ipa/*.ipa
```

---

## 📚 学习资源

### 官方文档
- **Flutter**: https://flutter.dev/docs
- **Dart**: https://dart.dev/guides
- **iOS**: https://developer.apple.com/documentation/

### 推荐教程
- Flutter 中文网：https://flutter.cn/
- Flutter 实战：https://book.flutterchina.club/
- iOS 开发指南：https://developer.apple.com/tutorials/

---

## 🆘 问题排查

### Flutter Doctor 问题

**Xcode 未找到**：
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

**iOS 工具链问题**：
```bash
brew uninstall --ignore-dependencies libimobiledevice
brew install --HEAD libimobiledevice
brew install ideviceinstaller
```

**CocoaPods 问题**：
```bash
sudo gem uninstall cocoapods
sudo gem install cocoapods
pod setup
```

---

## 💡 最佳实践

1. **定期更新**：
   ```bash
   brew update && brew upgrade
   flutter upgrade
   pod repo update
   ```

2. **清理缓存**：
   ```bash
   flutter clean
   rm -rf ios/Pods ios/Podfile.lock
   pod cache clean --all
   ```

3. **备份配置**：
   - 保存 `ios/` 目录配置
   - 备份证书和描述文件
   - 导出 Xcode 设置

4. **版本管理**：
   - 使用 `.gitignore` 排除 `Pods/`
   - 提交 `Podfile.lock`
   - 记录 Flutter SDK 版本

---

## 🎓 总结

### 最小安装清单（新手）
1. ✅ Xcode
2. ✅ Homebrew
3. ✅ Flutter SDK
4. ✅ CocoaPods
5. ✅ VS Code

### 完整安装清单（专业）
1. ✅ Xcode + Command Line Tools
2. ✅ Homebrew
3. ✅ Flutter SDK
4. ✅ CocoaPods
5. ✅ Git + GitHub SSH
6. ✅ VS Code + 插件
7. ✅ Android Studio（可选）
8. ✅ Fastlane（可选）
9. ✅ 其他工具

---

**准备就绪！开始你的 iOS 开发之旅吧！** 🚀
