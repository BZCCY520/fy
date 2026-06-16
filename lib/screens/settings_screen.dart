import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/liquid_glass_theme.dart';
import '../widgets/liquid_glass/liquid_glass_card.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
import '../settings_store.dart';
import '../emby_client.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsStore = SettingsStore();
  final _embyClient = EmbyClient();

  TranslationSettings _translationSettings = TranslationSettings.defaults;
  EmbySettings _embySettings = EmbySettings.defaults;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final translation = await _settingsStore.load();
    final emby = await _settingsStore.loadEmby();
    if (!mounted) return;
    setState(() {
      _translationSettings = translation;
      _embySettings = emby;
      _loading = false;
    });
  }

  Future<void> _showTranslationSettingsDialog() async {
    final endpointController =
        TextEditingController(text: _translationSettings.endpoint);
    final apiKeyController =
        TextEditingController(text: _translationSettings.apiKey);
    final modelController =
        TextEditingController(text: _translationSettings.model);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LiquidGlassTheme.background,
        title: const Text('AI 翻译设置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('Endpoint', endpointController),
              const SizedBox(height: 16),
              _buildTextField('API Key', apiKeyController, obscure: true),
              const SizedBox(height: 16),
              _buildTextField('Model', modelController),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final updated = TranslationSettings(
                endpoint: endpointController.text,
                apiKey: apiKeyController.text,
                model: modelController.text,
              );
              await _settingsStore.save(updated);
              setState(() => _translationSettings = updated);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEmbyConnectionDialog() async {
    final serverController =
        TextEditingController(text: _embySettings.serverUrl);
    final usernameController =
        TextEditingController(text: _embySettings.username);
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LiquidGlassTheme.background,
        title: const Text('连接 Emby'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('服务器地址', serverController),
              const SizedBox(height: 16),
              _buildTextField('用户名', usernameController),
              const SizedBox(height: 16),
              _buildTextField('密码', passwordController, obscure: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final session = await _embyClient.authenticate(
                  serverUrl: serverController.text,
                  username: usernameController.text,
                  password: passwordController.text,
                );
                final updated = EmbySettings(
                  serverUrl: serverController.text,
                  username: session.username,
                  userId: session.userId,
                  accessToken: session.accessToken,
                );
                await _settingsStore.saveEmby(updated);
                setState(() => _embySettings = updated);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Emby 连接成功')),
                  );
                }
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('连接失败：$error')),
                  );
                }
              }
            },
            child: const Text('连接'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: LiquidGlassTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: LiquidGlassTheme.textSecondary),
        filled: true,
        fillColor: LiquidGlassTheme.glassBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMedium),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidGlassTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: LiquidGlassTheme.accentBlue,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(LiquidGlassTheme.spaceM),
              children: [
                LiquidGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.sparkles,
                            color: _translationSettings.isReady
                                ? LiquidGlassTheme.success
                                : LiquidGlassTheme.textTertiary,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'AI 翻译',
                              style: TextStyle(
                                color: LiquidGlassTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (_translationSettings.isReady
                                      ? LiquidGlassTheme.success
                                      : LiquidGlassTheme.warning)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(
                                LiquidGlassTheme.radiusPill,
                              ),
                            ),
                            child: Text(
                              _translationSettings.isReady ? '已配置' : '待配置',
                              style: TextStyle(
                                color: _translationSettings.isReady
                                    ? LiquidGlassTheme.success
                                    : LiquidGlassTheme.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '配置 AI 翻译接口以使用字幕翻译功能',
                        style: TextStyle(
                          color: LiquidGlassTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LiquidGlassButton(
                        text: '配置',
                        icon: CupertinoIcons.settings,
                        onPressed: _showTranslationSettingsDialog,
                        width: double.infinity,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LiquidGlassTheme.spaceM),
                LiquidGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.tv,
                            color: _embySettings.hasToken
                                ? LiquidGlassTheme.success
                                : LiquidGlassTheme.textTertiary,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Emby 媒体服务器',
                              style: TextStyle(
                                color: LiquidGlassTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (_embySettings.hasToken
                                      ? LiquidGlassTheme.success
                                      : LiquidGlassTheme.warning)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(
                                LiquidGlassTheme.radiusPill,
                              ),
                            ),
                            child: Text(
                              _embySettings.hasToken ? '已连接' : '未连接',
                              style: TextStyle(
                                color: _embySettings.hasToken
                                    ? LiquidGlassTheme.success
                                    : LiquidGlassTheme.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_embySettings.hasToken) ...[
                        const SizedBox(height: 12),
                        Text(
                          '已连接：${_embySettings.username}',
                          style: TextStyle(
                            color: LiquidGlassTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        '连接 Emby 服务器以浏览和播放媒体库视频',
                        style: TextStyle(
                          color: LiquidGlassTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LiquidGlassButton(
                        text: _embySettings.hasToken ? '重新连接' : '连接',
                        icon: CupertinoIcons.link,
                        onPressed: _showEmbyConnectionDialog,
                        width: double.infinity,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LiquidGlassTheme.spaceM),
                LiquidGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            CupertinoIcons.info_circle,
                            color: LiquidGlassTheme.accentBlue,
                          ),
                          SizedBox(width: 12),
                          Text(
                            '关于',
                            style: TextStyle(
                              color: LiquidGlassTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('应用名称', 'AI 字幕'),
                      _buildInfoRow('版本', '2.0.0'),
                      _buildInfoRow('设计语言', 'Liquid Glass (iOS 26)'),
                      _buildInfoRow('功能', '视频播放 · AI 字幕翻译'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: LiquidGlassTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: LiquidGlassTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
