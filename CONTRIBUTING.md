# 贡献指南

感谢你有兴趣为 AI 字幕项目做出贡献！

## 行为准则

请阅读并遵守我们的行为准则，确保社区对所有人都友好和包容。

## 如何贡献

### 报告 Bug

在提交 Bug 之前，请先搜索现有的 Issues 确认问题是否已被报告。

创建 Bug 报告时，请包含：

- **清晰的标题和描述**
- **重现步骤**（尽可能详细）
- **预期行为**和**实际行为**
- **截图**（如果适用）
- **环境信息**（iOS 版本、设备型号、Flutter 版本等）

### 建议新功能

我们欢迎新功能建议！请通过 GitHub Issues 提交，并包含：

- **功能描述**
- **使用场景**
- **可能的实现方案**
- **是否愿意自己实现**

### Pull Request 流程

1. **Fork 仓库**并创建你的分支
   ```bash
   git checkout -b feature/my-new-feature
   ```

2. **开发新功能**
   - 遵循项目代码风格
   - 添加必要的测试
   - 更新相关文档

3. **测试你的更改**
   ```bash
   flutter analyze
   flutter test
   flutter run
   ```

4. **提交更改**
   ```bash
   git commit -m "feat: add amazing feature"
   ```
   
   提交信息格式：
   - `feat:` 新功能
   - `fix:` Bug 修复
   - `docs:` 文档更新
   - `style:` 代码格式（不影响功能）
   - `refactor:` 重构
   - `test:` 测试相关
   - `chore:` 构建/工具链相关

5. **推送到你的 Fork**
   ```bash
   git push origin feature/my-new-feature
   ```

6. **创建 Pull Request**
   - 填写 PR 模板
   - 关联相关 Issues
   - 等待代码审查

## 开发指南

### 环境设置

```bash
# 克隆仓库
git clone https://github.com/BZCCY520/fy.git
cd fy

# 安装依赖
flutter pub get

# 运行应用
flutter run
```

### 代码规范

#### Dart 代码风格

遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 规范：

```dart
// ✅ 好的示例
class LiquidGlassButton extends StatelessWidget {
  const LiquidGlassButton({
    super.key,
    required this.onPressed,
    this.text,
  });

  final VoidCallback onPressed;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      // ...
    );
  }
}
```

#### Liquid Glass 设计规范

所有 UI 组件应遵循 Liquid Glass 设计语言：

```dart
// 使用主题常量
import '../../theme/liquid_glass_theme.dart';

Container(
  decoration: BoxDecoration(
    color: LiquidGlassTheme.glassBackground,
    borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMedium),
    border: Border.all(color: LiquidGlassTheme.glassBorder),
  ),
)
```

#### 文件组织

```
lib/
├── main.dart                    # 应用入口
├── theme/                       # 主题配置
├── screens/                     # 页面级组件
├── widgets/                     # 可复用组件
│   ├── liquid_glass/           # Liquid Glass 组件
│   └── subtitle/               # 字幕相关组件
└── services/                    # 服务层（未来）
```

### 测试

#### 单元测试

```dart
test('should translate text correctly', () async {
  final translator = AiTranslator(client: mockClient);
  final result = await translator.translate(
    settings: settings,
    text: 'Hello',
    sourceLanguage: appLanguages[1],
    targetLanguage: appLanguages[0],
  );
  expect(result, '你好');
});
```

#### Widget 测试

```dart
testWidgets('loads AI subtitle app', (tester) async {
  await tester.pumpWidget(const AISubtitleApp());
  await tester.pumpAndSettle();
  
  expect(find.text('AI 字幕'), findsWidgets);
});
```

### 文档

- 为新功能添加注释
- 更新 README.md
- 更新 CHANGELOG.md
- 添加使用示例（如果适用）

## 设计资源

### Liquid Glass 参考

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- Liquid Glass 设计系统（iOS 26）

### 颜色系统

```dart
background: Color(0xFF000000)      // 纯黑背景
glassBackground: Color(0x33FFFFFF) // 半透明玻璃
glassBorder: Color(0x1AFFFFFF)     // 玻璃边框
accentBlue: Color(0xFF00A8FF)      // 强调色
textPrimary: Color(0xFFFFFFFF)     // 主文本
textSecondary: Color(0x99FFFFFF)   // 次要文本
```

### 动画规范

```dart
duration: Duration(milliseconds: 300)
curve: Curves.easeInOutCubic
scale: 0.95 - 1.0  // 点击缩放
```

## 审查流程

1. **自动化检查**
   - CI/CD 构建必须通过
   - 代码分析无错误
   - 所有测试通过

2. **代码审查**
   - 至少一位维护者审查
   - 遵循代码规范
   - 功能完整性
   - 性能考虑

3. **合并**
   - 审查通过后合并到 main 分支
   - 自动触发新构建

## 社区

- **GitHub Issues**: 讨论问题和新功能
- **Pull Requests**: 代码贡献
- **Discussions**: 一般性讨论

## 许可证

通过贡献代码，你同意你的贡献将在 [MIT License](LICENSE) 下发布。

---

再次感谢你的贡献！❤️
