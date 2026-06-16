import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../theme/liquid_glass_theme.dart';
import '../widgets/liquid_glass/liquid_glass_button.dart';
import '../widgets/subtitle/floating_subtitle.dart';
import '../ai_translator.dart';
import '../language_option.dart';
import '../settings_store.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    this.videoFile,
    this.videoUrl,
    required this.title,
  }) : assert(videoFile != null || videoUrl != null,
            'Must provide either videoFile or videoUrl');

  final File? videoFile;
  final String? videoUrl;
  final String title;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  final _translator = AiTranslator();
  final _settingsStore = SettingsStore();

  TranslationSettings _settings = TranslationSettings.defaults;
  LanguageOption _sourceLanguage = appLanguages[0]; // 中文
  LanguageOption _targetLanguage = appLanguages[1]; // 英文

  bool _controlsVisible = true;
  bool _subtitleVisible = true;
  bool _isTranslating = false;
  bool _loading = true;
  String _subtitle = '';
  String _originalText = '';
  Offset _subtitleOffset = const Offset(16, 100);
  Timer? _hideControlsTimer;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeVideo();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsStore.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
    });
  }

  Future<void> _initializeVideo() async {
    try {
      final controller = widget.videoFile != null
          ? VideoPlayerController.file(
              widget.videoFile!,
              videoPlayerOptions: VideoPlayerOptions(
                mixWithOthers: true,
                allowBackgroundPlayback: true,
              ),
            )
          : VideoPlayerController.networkUrl(
              Uri.parse(widget.videoUrl!),
              videoPlayerOptions: VideoPlayerOptions(
                mixWithOthers: true,
                allowBackgroundPlayback: true,
              ),
            );

      await controller.initialize();
      await controller.setLooping(false);
      controller.addListener(_onVideoChanged);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _loading = false;
      });

      await controller.play();
      _startHideControlsTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText = '视频加载失败：$error';
      });
    }
  }

  void _onVideoChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
        _hideControlsTimer?.cancel();
      } else {
        controller.play();
        _startHideControlsTimer();
      }
    });
  }

  void _showControls() {
    setState(() {
      _controlsVisible = true;
    });
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  void _showSubtitleInput() {
    final controller = TextEditingController(text: _originalText);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SubtitleInputSheet(
        controller: controller,
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
        onSourceLanguageChanged: (lang) {
          setState(() => _sourceLanguage = lang);
        },
        onTargetLanguageChanged: (lang) {
          setState(() => _targetLanguage = lang);
        },
        onTranslate: () async {
          Navigator.pop(context);
          await _translateText(controller.text);
        },
      ),
    );
  }

  Future<void> _translateText(String text) async {
    if (text.trim().isEmpty) return;
    if (!_settings.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在设置中配置 AI 翻译接口')),
      );
      return;
    }

    setState(() {
      _isTranslating = true;
      _originalText = text;
    });

    try {
      final translated = await _translator.translate(
        settings: _settings,
        text: text,
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
      );

      if (!mounted) return;
      setState(() {
        _subtitle = translated;
        _isTranslating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isTranslating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('翻译失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (_controlsVisible) {
            setState(() => _controlsVisible = false);
          } else {
            _showControls();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 视频播放器
            Center(
              child: _loading
                  ? const CircularProgressIndicator(
                      color: LiquidGlassTheme.accentBlue,
                    )
                  : _errorText != null
                      ? Center(
                          child: Text(
                            _errorText!,
                            style: const TextStyle(
                              color: LiquidGlassTheme.textPrimary,
                            ),
                          ),
                        )
                      : _controller != null &&
                              _controller!.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio,
                              child: VideoPlayer(_controller!),
                            )
                          : const SizedBox.shrink(),
            ),

            // 悬浮字幕
            if (_subtitleVisible && _subtitle.isNotEmpty)
              FloatingSubtitle(
                text: _subtitle,
                initialOffset: _subtitleOffset,
                maxSize: size,
                onPositionChanged: (offset) {
                  setState(() => _subtitleOffset = offset);
                },
              ),

            // 控制栏
            if (_controlsVisible) ...[
              _buildTopBar(),
              _buildBottomBar(),
            ],

            // 翻译中指示器
            if (_isTranslating)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(
                        LiquidGlassTheme.radiusMedium,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: LiquidGlassTheme.accentBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'AI 翻译中...',
                          style: TextStyle(
                            color: LiquidGlassTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            LiquidGlassButton(
              icon: CupertinoIcons.back,
              onPressed: () => Navigator.pop(context),
              width: 40,
              height: 40,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LiquidGlassTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            LiquidGlassButton(
              icon: _subtitleVisible
                  ? CupertinoIcons.captions_bubble_fill
                  : CupertinoIcons.captions_bubble,
              onPressed: () {
                setState(() => _subtitleVisible = !_subtitleVisible);
              },
              width: 40,
              height: 40,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final position = controller.value.position;
    final duration = controller.value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 14,
                ),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: (value) {
                  controller.seekTo(
                    Duration(
                      milliseconds: (duration.inMilliseconds * value).toInt(),
                    ),
                  );
                },
                activeColor: LiquidGlassTheme.accentBlue,
                inactiveColor: LiquidGlassTheme.glassBackground,
              ),
            ),
            const SizedBox(height: 8),
            // 控制按钮
            Row(
              children: [
                LiquidGlassButton(
                  icon: controller.value.isPlaying
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                  onPressed: _togglePlayPause,
                  width: 48,
                  height: 48,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 12),
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                  style: const TextStyle(
                    color: LiquidGlassTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                LiquidGlassButton(
                  icon: CupertinoIcons.textformat,
                  text: '字幕',
                  onPressed: _showSubtitleInput,
                  height: 48,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

// 字幕输入面板
class _SubtitleInputSheet extends StatelessWidget {
  const _SubtitleInputSheet({
    required this.controller,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.onSourceLanguageChanged,
    required this.onTargetLanguageChanged,
    required this.onTranslate,
  });

  final TextEditingController controller;
  final LanguageOption sourceLanguage;
  final LanguageOption targetLanguage;
  final ValueChanged<LanguageOption> onSourceLanguageChanged;
  final ValueChanged<LanguageOption> onTargetLanguageChanged;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: LiquidGlassTheme.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LiquidGlassTheme.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '输入要翻译的文本',
            style: TextStyle(
              color: LiquidGlassTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: LiquidGlassTheme.spaceM),
          TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(
              color: LiquidGlassTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: '输入或粘贴文本...',
              hintStyle: TextStyle(
                color: LiquidGlassTheme.textTertiary,
              ),
              filled: true,
              fillColor: LiquidGlassTheme.glassBackground,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(LiquidGlassTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: LiquidGlassTheme.spaceM),
          Row(
            children: [
              Expanded(
                child: _LanguageSelector(
                  label: '源语言',
                  value: sourceLanguage,
                  onChanged: onSourceLanguageChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LanguageSelector(
                  label: '目标语言',
                  value: targetLanguage,
                  onChanged: onTargetLanguageChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: LiquidGlassTheme.spaceL),
          SizedBox(
            width: double.infinity,
            child: LiquidGlassButton(
              text: '开始翻译',
              icon: CupertinoIcons.sparkles,
              onPressed: onTranslate,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final LanguageOption value;
  final ValueChanged<LanguageOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: LiquidGlassTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final selected = await showModalBottomSheet<LanguageOption>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => _LanguagePickerSheet(selected: value),
            );
            if (selected != null) {
              onChanged(selected);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: LiquidGlassTheme.glassBackground,
              borderRadius:
                  BorderRadius.circular(LiquidGlassTheme.radiusMedium),
              border: Border.all(
                color: LiquidGlassTheme.glassBorder,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.nativeName,
                    style: const TextStyle(
                      color: LiquidGlassTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 16,
                  color: LiquidGlassTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet({required this.selected});

  final LanguageOption selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: LiquidGlassTheme.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LiquidGlassTheme.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '选择语言',
            style: TextStyle(
              color: LiquidGlassTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: LiquidGlassTheme.spaceM),
          ...appLanguages.map((lang) => ListTile(
                title: Text(
                  lang.nativeName,
                  style: const TextStyle(
                    color: LiquidGlassTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  lang.name,
                  style: TextStyle(
                    color: LiquidGlassTheme.textSecondary,
                  ),
                ),
                trailing: lang.code == selected.code
                    ? const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: LiquidGlassTheme.accentBlue,
                      )
                    : null,
                onTap: () => Navigator.pop(context, lang),
              )),
        ],
      ),
    );
  }
}
