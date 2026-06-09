import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:video_player/video_player.dart';

import 'ai_translator.dart';
import 'language_option.dart';
import 'live_activity_bridge.dart';
import 'pip_bridge.dart';
import 'settings_store.dart';

void main() {
  runApp(const VoiceTranslatorApp());
}

class VoiceTranslatorApp extends StatelessWidget {
  const VoiceTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '声译 AI',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'SF Pro Display',
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFEAF8FF),
          secondary: Color(0xFF9BE7FF),
          tertiary: Color(0xFFD8B4FE),
          surface: Color(0xFF0A1020),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF08101E),
      ),
      home: const VoiceTranslatorHomePage(),
    );
  }
}

class SubtitleCue {
  const SubtitleCue({
    required this.original,
    required this.translation,
    required this.createdAt,
  });

  final String original;
  final String translation;
  final DateTime createdAt;
}

class VoiceTranslatorHomePage extends StatefulWidget {
  const VoiceTranslatorHomePage({super.key});

  @override
  State<VoiceTranslatorHomePage> createState() =>
      _VoiceTranslatorHomePageState();
}

class _VoiceTranslatorHomePageState extends State<VoiceTranslatorHomePage>
    with SingleTickerProviderStateMixin {
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  final _settingsStore = SettingsStore();
  final _translator = AiTranslator();
  final _liveActivity = LiveActivityBridge();
  final _pipBridge = PipBridge();

  late final AnimationController _pulseController;

  TranslationSettings _settings = TranslationSettings.defaults;
  LanguageOption _sourceLanguage = appLanguages[0];
  LanguageOption _targetLanguage = appLanguages[1];

  VideoPlayerController? _videoController;
  Offset _captionOffset = const Offset(18, 220);

  bool _speechReady = false;
  bool _settingsLoaded = false;
  bool _isListening = false;
  bool _isTranslating = false;
  bool _autoTranslateAfterStop = false;
  bool _continuousVideoTranslation = false;
  bool _videoLoading = false;
  bool _captionVisible = true;
  bool _pipEnabled = false;
  bool _pipSupported = false;
  int _mode = 1;
  double _soundLevel = 0;
  String _statusText = '正在准备语音识别…';
  String _transcript = '';
  String _translation = '';
  String _lastTranslatedSource = '';
  String? _errorText;
  String? _videoSourceLabel;
  final List<SubtitleCue> _subtitleHistory = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    unawaited(_loadSettings());
    unawaited(_loadPipSupport());
    unawaited(_configureTts());
    unawaited(_initializeSpeech());
    unawaited(_liveActivity.configureAudioSession());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.cancel();
    _tts.stop();
    _videoController?.removeListener(_onVideoChanged);
    _videoController?.dispose();
    unawaited(_liveActivity.end());
    unawaited(_pipBridge.stop());
    super.dispose();
  }

  Future<void> _loadPipSupport() async {
    final supported = await _pipBridge.isSupported();
    if (!mounted) {
      return;
    }
    setState(() {
      _pipSupported = supported;
    });
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _settingsLoaded = true;
    });
  }

  Future<void> _configureTts() async {
    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
    } catch (_) {
      // Plugin channels are unavailable in widget tests and on unsupported hosts.
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      final enabled = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _speechReady = enabled;
        _statusText = enabled ? '点击开始听译' : '语音识别不可用，请检查系统权限';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _speechReady = false;
        _statusText = '语音识别初始化失败';
        _errorText = error.toString();
      });
    }
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }

    final shouldTranslateOnce =
        _autoTranslateAfterStop &&
        (status == 'done' || status == 'notListening') &&
        _transcript.trim().isNotEmpty;
    final shouldTranslateContinuously =
        _continuousVideoTranslation &&
        !_speech.isListening &&
        !_isTranslating &&
        _transcript.trim().isNotEmpty &&
        _transcript.trim() != _lastTranslatedSource;

    setState(() {
      _isListening = _speech.isListening;
      if (_speech.isListening) {
        _statusText = _continuousVideoTranslation ? '视频听译中…' : '正在实时提取声音…';
      } else if (_transcript.trim().isEmpty) {
        _statusText = _continuousVideoTranslation ? '等待视频声音…' : '点击开始听译';
      } else if (!shouldTranslateOnce && !shouldTranslateContinuously) {
        _statusText = '声音提取完成，可继续翻译';
      }
    });

    if (shouldTranslateOnce) {
      _autoTranslateAfterStop = false;
      unawaited(_translateTranscript());
    } else if (shouldTranslateContinuously) {
      unawaited(_translateAndMaybeResumeVideoListening());
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isListening = false;
      _autoTranslateAfterStop = false;
      _continuousVideoTranslation = false;
      _pipEnabled = false;
      _statusText = '声音提取中断';
      _errorText = '${error.errorMsg}${error.permanent ? '（永久错误）' : ''}';
    });
    unawaited(_liveActivity.end());
    unawaited(_pipBridge.stop());
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) {
      return;
    }
    setState(() {
      _transcript = result.recognizedWords;
      _errorText = null;
      if (result.finalResult) {
        _statusText = _continuousVideoTranslation
            ? '正在生成字幕…'
            : '声音提取完成，正在准备翻译…';
      }
    });

    if (_continuousVideoTranslation) {
      unawaited(_pushLiveActivity(status: '正在听译'));
      unawaited(_pushPip(status: '正在听译'));
      if (result.finalResult) {
        unawaited(_translateAndMaybeResumeVideoListening());
      }
    }
  }

  void _onVideoChanged() {
    if (!mounted) {
      return;
    }
    final controller = _videoController;
    if (controller == null) {
      return;
    }
    if (_continuousVideoTranslation &&
        controller.value.isInitialized &&
        !controller.value.isPlaying &&
        controller.value.position >= controller.value.duration) {
      unawaited(_stopVideoTranslation());
    }
    setState(() {});
  }

  Future<void> _toggleListening() async {
    HapticFeedback.mediumImpact();
    if (_speech.isListening || _isListening) {
      await _stopListening(translateAfterStop: true);
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening({
    bool continuousVideo = false,
    bool clearText = true,
  }) async {
    if (!_speechReady) {
      await _initializeSpeech();
    }
    if (!_speechReady) {
      setState(() {
        _errorText = '当前设备没有授权麦克风或语音识别权限。';
      });
      return;
    }

    await _liveActivity.configureAudioSession();
    await _tts.stop();
    setState(() {
      _isListening = true;
      _isTranslating = false;
      _autoTranslateAfterStop = !continuousVideo;
      _continuousVideoTranslation = continuousVideo;
      _soundLevel = 0;
      if (clearText) {
        _transcript = '';
      }
      if (!continuousVideo) {
        _translation = '';
        _lastTranslatedSource = '';
      }
      _errorText = null;
      _statusText = continuousVideo ? '视频听译中…' : '正在实时提取声音…';
    });

    await _speech.listen(
      onResult: _handleSpeechResult,
      onSoundLevelChange: (level) {
        if (!mounted) {
          return;
        }
        setState(() {
          _soundLevel = level;
        });
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: _sourceLanguage.localeId,
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        autoPunctuation: true,
        enableHapticFeedback: true,
        pauseFor: continuousVideo
            ? const Duration(milliseconds: 1300)
            : const Duration(seconds: 3),
        listenFor: continuousVideo
            ? const Duration(seconds: 18)
            : const Duration(minutes: 1),
      ),
    );
  }

  Future<void> _stopListening({required bool translateAfterStop}) async {
    _autoTranslateAfterStop = translateAfterStop;
    _continuousVideoTranslation = false;
    setState(() {
      _isListening = false;
      _statusText = translateAfterStop ? '正在收束语音结果…' : '已停止声音提取';
    });
    await _speech.stop();
    if (translateAfterStop && _transcript.trim().isNotEmpty) {
      _autoTranslateAfterStop = false;
      await _translateTranscript();
    }
    await _liveActivity.end();
  }

  Future<void> _translateAndMaybeResumeVideoListening() async {
    if (_isTranslating) {
      return;
    }
    await _translateTranscript();
    final controller = _videoController;
    if (!mounted ||
        !_continuousVideoTranslation ||
        controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isPlaying) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (mounted && !_speech.isListening && _continuousVideoTranslation) {
      await _startListening(continuousVideo: true);
    }
  }

  Future<void> _translateTranscript() async {
    final text = _transcript.trim();
    if (text.isEmpty) {
      setState(() {
        _statusText = '还没有提取到可翻译的声音文本';
      });
      return;
    }
    if (text == _lastTranslatedSource && _translation.trim().isNotEmpty) {
      return;
    }
    if (!_settings.isReady) {
      setState(() {
        _statusText = '需要先配置 AI 翻译接口';
        _errorText = '请点击右上角设置，填写 Endpoint 和 Model。API Key 可留空用于无鉴权网关。';
      });
      await _pushLiveActivity(status: '待配置 AI');
      await _pushPip(status: '待配置 AI');
      return;
    }

    setState(() {
      _isTranslating = true;
      _errorText = null;
      _statusText = _continuousVideoTranslation ? 'AI 正在生成字幕…' : 'AI 正在翻译…';
    });
    await _pushLiveActivity(status: 'AI 翻译中');
    await _pushPip(status: 'AI 翻译中');

    try {
      final translated = await _translator.translate(
        settings: _settings,
        text: text,
        sourceLanguage: _sourceLanguage,
        targetLanguage: _targetLanguage,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _lastTranslatedSource = text;
        _translation = translated;
        _subtitleHistory.insert(
          0,
          SubtitleCue(
            original: text,
            translation: translated,
            createdAt: DateTime.now(),
          ),
        );
        if (_subtitleHistory.length > 20) {
          _subtitleHistory.removeRange(20, _subtitleHistory.length);
        }
        _statusText = _continuousVideoTranslation ? '字幕已更新' : '翻译完成';
      });
      await _pushLiveActivity(status: '字幕已更新');
      await _pushPip(status: '字幕已更新');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.toString();
        _statusText = '翻译失败';
      });
      await _pushLiveActivity(status: '翻译失败');
      await _pushPip(status: '翻译失败');
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  Future<void> _speakTranslation() async {
    if (_translation.trim().isEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    await _tts.setLanguage(_targetLanguage.ttsLocale);
    await _tts.speak(_translation);
  }

  Future<void> _pickLocalVideo() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) {
      return;
    }
    await _loadVideoController(
      VideoPlayerController.file(
        File(path),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: true,
        ),
      ),
      label: result!.files.single.name,
    );
  }

  Future<void> _openNetworkVideoSheet() async {
    final url = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _VideoUrlSheet(),
    );
    if (url == null || url.trim().isEmpty) {
      return;
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() {
        _errorText = '视频 URL 无效，请输入完整 https:// 地址。';
      });
      return;
    }
    await _loadVideoController(
      VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: true,
        ),
      ),
      label: uri.host,
    );
  }

  Future<void> _loadVideoController(
    VideoPlayerController controller, {
    required String label,
  }) async {
    await _stopVideoTranslation(silent: true);
    setState(() {
      _videoLoading = true;
      _videoSourceLabel = label;
      _errorText = null;
      _translation = '';
      _transcript = '';
      _lastTranslatedSource = '';
      _subtitleHistory.clear();
      _statusText = '正在载入视频…';
    });

    final old = _videoController;
    old?.removeListener(_onVideoChanged);
    await old?.dispose();

    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(1);
      controller.addListener(_onVideoChanged);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
        _videoLoading = false;
        _captionOffset = const Offset(18, 220);
        _statusText = '视频已就绪，点击“开始视频听译”';
      });
    } catch (error) {
      await controller.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _videoController = null;
        _videoLoading = false;
        _statusText = '视频载入失败';
        _errorText = error.toString();
      });
    }
  }

  Future<void> _toggleVideoPlayback() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    HapticFeedback.selectionClick();
    await _liveActivity.configureAudioSession();
    if (controller.value.isPlaying) {
      await controller.pause();
      if (_continuousVideoTranslation) {
        await _speech.stop();
      }
      setState(() {
        _statusText = '视频已暂停';
      });
      await _pushLiveActivity(status: '视频已暂停');
      await _pushPip(status: '视频已暂停');
    } else {
      await controller.play();
      setState(() {
        _statusText = _continuousVideoTranslation ? '视频听译中…' : '视频播放中';
      });
      if (_continuousVideoTranslation && !_speech.isListening) {
        await _startListening(continuousVideo: true);
      }
      await _pushLiveActivity(
        status: _continuousVideoTranslation ? '视频听译中' : '视频播放中',
      );
      await _pushPip(status: _continuousVideoTranslation ? '视频听译中' : '视频播放中');
    }
  }

  Future<void> _startVideoTranslation() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      setState(() {
        _errorText = '请先选择本地视频或输入网络视频 URL。';
      });
      return;
    }
    HapticFeedback.mediumImpact();
    await _liveActivity.configureAudioSession();
    if (!controller.value.isPlaying) {
      await controller.play();
    }
    setState(() {
      _mode = 1;
      _captionVisible = true;
      _continuousVideoTranslation = true;
      _statusText = '视频听译中…';
      _errorText = null;
    });
    await _liveActivity.start(
      sourceLanguage: _sourceLanguage.nativeName,
      targetLanguage: _targetLanguage.nativeName,
      status: '视频听译中',
      transcript: _transcript,
      translation: _translation,
    );
    if (_pipEnabled) {
      await _pipBridge.start(
        sourceLanguage: _sourceLanguage.nativeName,
        targetLanguage: _targetLanguage.nativeName,
        status: '视频听译中',
        transcript: _transcript,
        translation: _translation,
      );
    }
    await _startListening(continuousVideo: true);
  }

  Future<void> _stopVideoTranslation({bool silent = false}) async {
    final wasActive = _continuousVideoTranslation || _speech.isListening;
    _continuousVideoTranslation = false;
    _autoTranslateAfterStop = false;
    if (_speech.isListening) {
      await _speech.stop();
    }
    if (!silent && wasActive && mounted) {
      setState(() {
        _isListening = false;
        _pipEnabled = false;
        _statusText = '视频听译已停止';
      });
    } else {
      _pipEnabled = false;
    }
    await _liveActivity.end();
    await _pipBridge.stop();
  }

  Future<void> _togglePipMode() async {
    HapticFeedback.selectionClick();
    if (!_pipSupported) {
      setState(() {
        _errorText = '当前设备或运行环境不支持系统画中画。请在 iPhone/iPad 真机上验证。';
      });
      return;
    }

    final next = !_pipEnabled;
    setState(() {
      _pipEnabled = next;
      _statusText = next ? '后台小窗已开启' : '后台小窗已关闭';
      _errorText = null;
    });

    if (next) {
      final started = await _pipBridge.start(
        sourceLanguage: _sourceLanguage.nativeName,
        targetLanguage: _targetLanguage.nativeName,
        status: _continuousVideoTranslation ? '视频听译中' : '后台小窗已开启',
        transcript: _transcript,
        translation: _translation,
      );
      if (!started && mounted) {
        setState(() {
          _pipEnabled = false;
          _statusText = '后台小窗启动失败';
          _errorText = '系统画中画未能启动；主界面字幕和灵动岛/Live Activity 仍可继续使用。';
        });
      }
    } else {
      await _pipBridge.stop();
    }
  }

  void _swapLanguages() {
    HapticFeedback.selectionClick();
    setState(() {
      final previousSource = _sourceLanguage;
      final previousTranscript = _transcript;
      final previousTranslation = _translation;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = previousSource;
      _transcript = previousTranslation;
      _translation = previousTranscript;
      _lastTranslatedSource = '';
      _statusText = '已切换语言方向';
    });
  }

  Future<void> _pickLanguage({required bool source}) async {
    final picked = await showModalBottomSheet<LanguageOption>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _LanguagePickerSheet(
          title: source ? '选择识别语言' : '选择目标语言',
          selected: source ? _sourceLanguage : _targetLanguage,
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (source) {
        _sourceLanguage = picked;
      } else {
        _targetLanguage = picked;
      }
    });
  }

  Future<void> _openSettingsSheet() async {
    final updated = await showModalBottomSheet<TranslationSettings>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _SettingsSheet(settings: _settings);
      },
    );
    if (updated == null || !mounted) {
      return;
    }
    await _settingsStore.save(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = updated;
      _settingsLoaded = true;
      _statusText = updated.isReady ? 'AI 翻译接口已连接' : '需要先配置 AI 翻译接口';
      _errorText = null;
    });
  }

  Future<void> _pushLiveActivity({required String status}) async {
    await _liveActivity.update(
      sourceLanguage: _sourceLanguage.nativeName,
      targetLanguage: _targetLanguage.nativeName,
      status: status,
      transcript: _transcript,
      translation: _translation,
    );
  }

  Future<void> _pushPip({required String status}) async {
    if (!_pipEnabled) {
      return;
    }
    await _pipBridge.update(
      sourceLanguage: _sourceLanguage.nativeName,
      targetLanguage: _targetLanguage.nativeName,
      status: status,
      transcript: _transcript,
      translation: _translation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: [
          _AuroraBackground(animation: _pulseController),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    math.max(24, bottomInset + 24),
                  ),
                  sliver: SliverList.list(
                    children: [
                      _Header(
                        connected: _settingsLoaded && _settings.isReady,
                        onSettings: _openSettingsSheet,
                      ),
                      const SizedBox(height: 16),
                      _ModeSwitch(
                        value: _mode,
                        onChanged: (value) => setState(() => _mode = value),
                      ),
                      const SizedBox(height: 16),
                      _LanguageBridge(
                        sourceLanguage: _sourceLanguage,
                        targetLanguage: _targetLanguage,
                        onPickSource: () => _pickLanguage(source: true),
                        onPickTarget: () => _pickLanguage(source: false),
                        onSwap: _swapLanguages,
                      ),
                      const SizedBox(height: 16),
                      _PipControlPanel(
                        enabled: _pipEnabled,
                        supported: _pipSupported,
                        transcript: _transcript,
                        translation: _translation,
                        onToggle: _togglePipMode,
                      ),
                      const SizedBox(height: 16),
                      if (_mode == 1)
                        _VideoTranslatePanel(
                          controller: _videoController,
                          videoLoading: _videoLoading,
                          sourceLabel: _videoSourceLabel,
                          captionVisible: _captionVisible,
                          captionOffset: _captionOffset,
                          transcript: _transcript,
                          translation: _translation,
                          active: _continuousVideoTranslation,
                          translating: _isTranslating,
                          onPickLocal: _pickLocalVideo,
                          onOpenUrl: _openNetworkVideoSheet,
                          onPlayPause: _toggleVideoPlayback,
                          onStart: _startVideoTranslation,
                          onStop: _stopVideoTranslation,
                          onToggleCaption: () => setState(
                            () => _captionVisible = !_captionVisible,
                          ),
                          onCaptionDrag: (offset) =>
                              setState(() => _captionOffset = offset),
                        )
                      else
                        _RecorderPanel(
                          statusText: _statusText,
                          isListening: _isListening,
                          isTranslating: _isTranslating,
                          speechReady: _speechReady,
                          soundLevel: _soundLevel,
                          pulse: _pulseController,
                          onToggle: _toggleListening,
                          onTranslate: _translateTranscript,
                        ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 14),
                        _ErrorBanner(message: _errorText!),
                      ],
                      const SizedBox(height: 14),
                      _GlassTextPanel(
                        title: _mode == 1 ? '当前原声字幕' : '声音提取文本',
                        subtitle: _sourceLanguage.label,
                        icon: CupertinoIcons.waveform,
                        text: _transcript,
                        placeholder: _mode == 1
                            ? '播放视频并开始视频听译后，系统会用麦克风提取视频声音。'
                            : '按下语音按钮开始说话，实时转写内容会显示在这里。',
                      ),
                      const SizedBox(height: 14),
                      _GlassTextPanel(
                        title: _mode == 1 ? '悬浮译文字幕' : 'AI 翻译结果',
                        subtitle: _targetLanguage.label,
                        icon: CupertinoIcons.sparkles,
                        text: _translation,
                        placeholder: _settings.isReady
                            ? '翻译结果会在声音提取结束后自动出现。'
                            : '请先在设置中填写 AI 翻译接口。',
                        trailing: _translation.trim().isEmpty
                            ? null
                            : _GlassIconButton(
                                icon: CupertinoIcons.speaker_2_fill,
                                tooltip: '朗读译文',
                                onTap: _speakTranslation,
                              ),
                      ),
                      if (_subtitleHistory.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _SubtitleHistoryPanel(history: _subtitleHistory),
                      ],
                      const SizedBox(height: 18),
                      _PrivacyNote(settingsReady: _settings.isReady),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.connected, required this.onSettings});

  final bool connected;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 34,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      tint: Colors.white.withValues(alpha: 0.075),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  const Color(0xFFBEEBFF).withValues(alpha: 0.78),
                  const Color(0xFFB794F6).withValues(alpha: 0.68),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7DD3FC).withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              CupertinoIcons.waveform_path_badge_plus,
              color: Color(0xFF07111F),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Colors.white,
                      Color(0xFFDDF7FF),
                      Color(0xFFE9D5FF),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    '声译 AI',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.1,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Liquid Glass · 实时字幕 · 灵动岛接口',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ConnectionPill(connected: connected),
              const SizedBox(height: 8),
              _GlassIconButton(
                icon: CupertinoIcons.slider_horizontal_3,
                tooltip: '设置',
                onTap: onSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 999,
      padding: const EdgeInsets.all(5),
      child: CupertinoSlidingSegmentedControl<int>(
        groupValue: value,
        backgroundColor: Colors.transparent,
        thumbColor: Colors.white.withValues(alpha: 0.26),
        children: const {
          0: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text('语音翻译', style: TextStyle(color: Colors.white)),
          ),
          1: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text('视频听译', style: TextStyle(color: Colors.white)),
          ),
        },
        onValueChanged: (next) {
          if (next != null) {
            onChanged(next);
          }
        },
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      tint: (connected ? const Color(0xFFBFFFE7) : const Color(0xFFFFE5B4))
          .withValues(alpha: 0.14),
      borderAlpha: connected ? 0.30 : 0.24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected
                  ? const Color(0xFF34D399)
                  : const Color(0xFFFFB86B),
              boxShadow: [
                BoxShadow(
                  color:
                      (connected
                              ? const Color(0xFF34D399)
                              : const Color(0xFFFFB86B))
                          .withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            connected ? '已连接' : '待配置',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageBridge extends StatelessWidget {
  const _LanguageBridge({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.onPickSource,
    required this.onPickTarget,
    required this.onSwap,
  });

  final LanguageOption sourceLanguage;
  final LanguageOption targetLanguage;
  final VoidCallback onPickSource;
  final VoidCallback onPickTarget;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(12),
      radius: 32,
      child: Row(
        children: [
          Expanded(
            child: _LanguageChip(
              eyebrow: '识别',
              language: sourceLanguage,
              onTap: onPickSource,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _GlassIconButton(
              icon: CupertinoIcons.arrow_left_right,
              tooltip: '交换语言',
              onTap: onSwap,
            ),
          ),
          Expanded(
            child: _LanguageChip(
              eyebrow: '翻译为',
              language: targetLanguage,
              onTap: onPickTarget,
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.eyebrow,
    required this.language,
    required this.onTap,
    this.alignEnd = false,
  });

  final String eyebrow;
  final LanguageOption language;
  final VoidCallback onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _LiquidSurface(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        tint: Colors.white.withValues(alpha: 0.055),
        child: Column(
          crossAxisAlignment: alignEnd
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.48),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: alignEnd
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    language.nativeName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 15,
                  color: Colors.white.withValues(alpha: 0.62),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              language.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PipControlPanel extends StatelessWidget {
  const _PipControlPanel({
    required this.enabled,
    required this.supported,
    required this.transcript,
    required this.translation,
    required this.onToggle,
  });

  final bool enabled;
  final bool supported;
  final String transcript;
  final String translation;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final preview = translation.trim().isNotEmpty
        ? translation.trim()
        : (transcript.trim().isNotEmpty
              ? transcript.trim()
              : '识别与翻译结果会同步显示在系统画中画小窗。');
    return _GlassPanel(
      radius: 32,
      padding: const EdgeInsets.all(14),
      tint: (enabled ? const Color(0xFFBFFFE7) : Colors.white).withValues(
        alpha: enabled ? 0.12 : 0.075,
      ),
      borderAlpha: enabled ? 0.34 : 0.20,
      child: Row(
        children: [
          _LiquidSurface(
            radius: 22,
            padding: EdgeInsets.zero,
            tint: Colors.white.withValues(alpha: 0.09),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(
                enabled
                    ? CupertinoIcons.rectangle_fill_on_rectangle_fill
                    : CupertinoIcons.rectangle_on_rectangle,
                color: supported
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.38),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        enabled ? '后台小窗已开启' : '后台小窗 / 画中画',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (supported
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFFFB86B))
                                .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        supported ? 'PiP' : '需真机',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 54,
              height: 32,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: (enabled ? const Color(0xFF34D399) : Colors.white)
                    .withValues(alpha: enabled ? 0.30 : 0.12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: enabled ? 0.36 : 0.18),
                ),
              ),
              child: Align(
                alignment: enabled
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: supported
                        ? Colors.white.withValues(alpha: 0.94)
                        : Colors.white.withValues(alpha: 0.48),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoTranslatePanel extends StatelessWidget {
  const _VideoTranslatePanel({
    required this.controller,
    required this.videoLoading,
    required this.sourceLabel,
    required this.captionVisible,
    required this.captionOffset,
    required this.transcript,
    required this.translation,
    required this.active,
    required this.translating,
    required this.onPickLocal,
    required this.onOpenUrl,
    required this.onPlayPause,
    required this.onStart,
    required this.onStop,
    required this.onToggleCaption,
    required this.onCaptionDrag,
  });

  final VideoPlayerController? controller;
  final bool videoLoading;
  final String? sourceLabel;
  final bool captionVisible;
  final Offset captionOffset;
  final String transcript;
  final String translation;
  final bool active;
  final bool translating;
  final VoidCallback onPickLocal;
  final VoidCallback onOpenUrl;
  final VoidCallback onPlayPause;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onToggleCaption;
  final ValueChanged<Offset> onCaptionDrag;

  @override
  Widget build(BuildContext context) {
    final ready = controller?.value.isInitialized ?? false;
    final playing = controller?.value.isPlaying ?? false;
    return _GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sourceLabel ?? '选择视频开始实时听译',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _GlassIconButton(
                icon: captionVisible
                    ? CupertinoIcons.captions_bubble_fill
                    : CupertinoIcons.captions_bubble,
                tooltip: '显示/隐藏悬浮字幕',
                onTap: onToggleCaption,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LiquidSurface(
            radius: 28,
            padding: const EdgeInsets.all(1.2),
            tint: Colors.white.withValues(alpha: 0.045),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: AspectRatio(
                aspectRatio: ready
                    ? math.max(0.8, controller!.value.aspectRatio)
                    : 16 / 9,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.44),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF0B1224),
                                Colors.black.withValues(alpha: 0.72),
                                const Color(0xFF15112A),
                              ],
                            ),
                          ),
                          child: ready
                              ? VideoPlayer(controller!)
                              : Center(
                                  child: videoLoading
                                      ? const CupertinoActivityIndicator(
                                          color: Colors.white,
                                        )
                                      : Icon(
                                          CupertinoIcons.play_rectangle_fill,
                                          size: 58,
                                          color: Colors.white.withValues(
                                            alpha: 0.42,
                                          ),
                                        ),
                                ),
                        ),
                        const _GlassSheen(radius: 27),
                        if (captionVisible)
                          _FloatingCaption(
                            offset: captionOffset,
                            maxSize: constraints.biggest,
                            active: active,
                            translating: translating,
                            transcript: transcript,
                            translation: translation,
                            onDrag: onCaptionDrag,
                          ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: _VideoControlsBar(
                            controller: controller,
                            ready: ready,
                            playing: playing,
                            active: active,
                            onPlayPause: onPlayPause,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (ready) VideoProgressIndicator(controller!, allowScrubbing: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LiquidActionButton(
                  label: '本地视频',
                  icon: CupertinoIcons.folder_fill,
                  enabled: !active,
                  onTap: onPickLocal,
                  subtle: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LiquidActionButton(
                  label: '视频 URL',
                  icon: CupertinoIcons.link,
                  enabled: !active,
                  onTap: onOpenUrl,
                  subtle: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LiquidActionButton(
            label: active ? '停止视频听译' : '开始视频听译',
            icon: active
                ? CupertinoIcons.stop_circle_fill
                : CupertinoIcons.captions_bubble_fill,
            enabled: ready,
            onTap: active ? onStop : onStart,
          ),
        ],
      ),
    );
  }
}

class _VideoControlsBar extends StatelessWidget {
  const _VideoControlsBar({
    required this.controller,
    required this.ready,
    required this.playing,
    required this.active,
    required this.onPlayPause,
  });

  final VideoPlayerController? controller;
  final bool ready;
  final bool playing;
  final bool active;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    final value = controller?.value;
    final position = value?.position ?? Duration.zero;
    final duration = value?.duration ?? Duration.zero;
    return _GlassPanel(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tint: Colors.black.withValues(alpha: 0.28),
      borderAlpha: 0.30,
      child: Row(
        children: [
          GestureDetector(
            onTap: ready ? onPlayPause : null,
            child: Icon(
              playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ready
                  ? '${_formatDuration(position)} / ${_formatDuration(duration)}'
                  : '等待视频',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (active ? const Color(0xFF34D399) : Colors.white)
                  .withValues(alpha: active ? 0.30 : 0.11),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              active ? '字幕中' : '待机',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingCaption extends StatelessWidget {
  const _FloatingCaption({
    required this.offset,
    required this.maxSize,
    required this.active,
    required this.translating,
    required this.transcript,
    required this.translation,
    required this.onDrag,
  });

  final Offset offset;
  final Size maxSize;
  final bool active;
  final bool translating;
  final String transcript;
  final String translation;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    final maxWidth = math.max(180.0, maxSize.width - 32);
    final maxHeight = math.max(80.0, maxSize.height - 86);
    final clampedOffset = Offset(
      offset.dx.clamp(8.0, math.max(8.0, maxSize.width - maxWidth - 8)),
      offset.dy.clamp(8.0, maxHeight),
    );
    final primary = translation.trim().isNotEmpty
        ? translation.trim()
        : (transcript.trim().isNotEmpty ? transcript.trim() : '字幕悬浮窗');
    final secondary = translation.trim().isNotEmpty ? transcript.trim() : '';

    return Positioned(
      left: clampedOffset.dx,
      top: clampedOffset.dy,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(clampedOffset + details.delta),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: _GlassPanel(
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            tint: Colors.black.withValues(alpha: 0.34),
            borderAlpha: 0.34,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      active
                          ? CupertinoIcons.waveform_circle_fill
                          : CupertinoIcons.captions_bubble_fill,
                      color: active
                          ? const Color(0xFF7DD3FC)
                          : Colors.white.withValues(alpha: 0.72),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      translating ? 'AI 正在生成字幕' : (active ? '实时字幕' : '预览'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.64),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  primary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.24,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black, blurRadius: 12)],
                  ),
                ),
                if (secondary.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    secondary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.56),
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecorderPanel extends StatelessWidget {
  const _RecorderPanel({
    required this.statusText,
    required this.isListening,
    required this.isTranslating,
    required this.speechReady,
    required this.soundLevel,
    required this.pulse,
    required this.onToggle,
    required this.onTranslate,
  });

  final String statusText;
  final bool isListening;
  final bool isTranslating;
  final bool speechReady;
  final double soundLevel;
  final Animation<double> pulse;
  final VoidCallback onToggle;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    final level = (soundLevel.clamp(-2, 10) + 2) / 12;
    return _GlassPanel(
      radius: 36,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        children: [
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final pulseValue = isListening ? pulse.value : 0.18;
              final scale = 1 + level * 0.12 + pulseValue * 0.04;
              return Transform.scale(scale: scale, child: child);
            },
            child: GestureDetector(
              onTap: onToggle,
              child: _LiquidOrb(
                size: 132,
                active: isListening,
                child: Icon(
                  isListening
                      ? CupertinoIcons.stop_fill
                      : CupertinoIcons.mic_fill,
                  size: 44,
                  color: const Color(0xFF07111F).withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 8,
                  width: 70 + level * 180,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFBEEBFF).withValues(alpha: 0.9),
                        const Color(0xFFE9D5FF).withValues(alpha: 0.86),
                        const Color(0xFF86EFAC).withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7DD3FC).withValues(alpha: 0.28),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _LiquidActionButton(
                  label: isListening ? '结束并翻译' : '开始声音提取',
                  icon: isListening
                      ? CupertinoIcons.stop_circle_fill
                      : CupertinoIcons.waveform_circle_fill,
                  enabled: speechReady && !isTranslating,
                  onTap: onToggle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LiquidActionButton(
                  label: isTranslating ? '翻译中…' : '手动翻译',
                  icon: CupertinoIcons.sparkles,
                  enabled: !isListening && !isTranslating,
                  onTap: onTranslate,
                  subtle: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiquidActionButton extends StatelessWidget {
  const _LiquidActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.subtle = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final foreground = subtle || !enabled
        ? Colors.white.withValues(alpha: enabled ? 0.92 : 0.42)
        : const Color(0xFF07111F);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: enabled ? 1 : 0.995,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            gradient: enabled && !subtle
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFCFF5FF),
                      Color(0xFFE9D5FF),
                    ],
                  )
                : null,
            color: enabled
                ? (subtle ? Colors.white.withValues(alpha: 0.105) : null)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: enabled ? 0.36 : 0.12),
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: (subtle ? Colors.black : const Color(0xFF7DD3FC))
                          .withValues(alpha: subtle ? 0.16 : 0.24),
                      blurRadius: subtle ? 16 : 28,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.20),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassTextPanel extends StatelessWidget {
  const _GlassTextPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.text,
    required this.placeholder,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String text;
  final String placeholder;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hasText = text.trim().isNotEmpty;
    return _GlassPanel(
      radius: 34,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LiquidSurface(
                radius: 999,
                padding: EdgeInsets.zero,
                tint: Colors.white.withValues(alpha: 0.08),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                  child: Icon(icon, color: Colors.white, size: 19),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              hasText ? text : placeholder,
              key: ValueKey(hasText ? text : placeholder),
              style: TextStyle(
                color: hasText
                    ? Colors.white.withValues(alpha: 0.93)
                    : Colors.white.withValues(alpha: 0.38),
                fontSize: hasText ? 21 : 16,
                height: 1.35,
                fontWeight: hasText ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: hasText ? -0.2 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtitleHistoryPanel extends StatelessWidget {
  const _SubtitleHistoryPanel({required this.history});

  final List<SubtitleCue> history;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '字幕记录',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          for (final cue in history.take(5)) ...[
            Text(
              cue.translation,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cue.original,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.46),
                fontSize: 12,
                height: 1.25,
              ),
            ),
            if (cue != history.take(5).last)
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 18),
          ],
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      tint: const Color(0xFFFF5A7A).withValues(alpha: 0.13),
      borderAlpha: 0.22,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Color(0xFFFFB4C2),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.settingsReady});

  final bool settingsReady;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      tint: Colors.white.withValues(alpha: 0.07),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            settingsReady
                ? CupertinoIcons.lock_shield_fill
                : CupertinoIcons.info_circle_fill,
            color: Colors.white.withValues(alpha: 0.72),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              settingsReady
                  ? 'iOS 不允许普通 App 覆盖到任意第三方 App 上方。本版本提供应用内悬浮字幕、后台音频播放配置与灵动岛接口；视频声音通过麦克风实时提取。'
                  : '请先配置 AI 接口。GitHub 可构建 unsigned IPA；灵动岛/后台能力最终仍需要 Apple 开发者签名与真机验证。',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet({required this.title, required this.selected});

  final String title;
  final LanguageOption selected;

  @override
  Widget build(BuildContext context) {
    return _BottomGlassSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: appLanguages.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              itemBuilder: (context, index) {
                final language = appLanguages[index];
                final isSelected = language.code == selected.code;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    language.nativeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    language.name,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          color: Color(0xFF7DD3FC),
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(language),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.settings});

  final TranslationSettings settings;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final TextEditingController _endpointController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  bool _hideKey = true;

  @override
  void initState() {
    super.initState();
    _endpointController = TextEditingController(text: widget.settings.endpoint);
    _apiKeyController = TextEditingController(text: widget.settings.apiKey);
    _modelController = TextEditingController(text: widget.settings.model);
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BottomGlassSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'AI 翻译接口',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _GlassIconButton(
                icon: CupertinoIcons.xmark,
                tooltip: '关闭',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '兼容 Chat Completions 格式。默认 Endpoint 可用于 OpenAI，也可替换为你的私有网关；API Key 留空时将不发送 Authorization 鉴权头。',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          _GlassTextField(
            label: 'Endpoint',
            controller: _endpointController,
            keyboardType: TextInputType.url,
            placeholder: 'https://api.openai.com/v1/chat/completions',
          ),
          const SizedBox(height: 12),
          _GlassTextField(
            label: 'API Key',
            controller: _apiKeyController,
            placeholder: '可留空；填写 sk-... 时使用 Bearer 鉴权',
            obscureText: _hideKey,
            suffix: IconButton(
              onPressed: () => setState(() => _hideKey = !_hideKey),
              icon: Icon(
                _hideKey ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _GlassTextField(
            label: 'Model',
            controller: _modelController,
            placeholder: 'gpt-4.1-mini',
          ),
          const SizedBox(height: 18),
          _LiquidActionButton(
            label: '保存并连接',
            icon: CupertinoIcons.checkmark_seal_fill,
            enabled: true,
            onTap: () {
              final updated = TranslationSettings(
                endpoint: _endpointController.text,
                apiKey: _apiKeyController.text,
                model: _modelController.text,
              );
              Navigator.of(context).pop(updated);
            },
          ),
        ],
      ),
    );
  }
}

class _VideoUrlSheet extends StatefulWidget {
  const _VideoUrlSheet();

  @override
  State<_VideoUrlSheet> createState() => _VideoUrlSheetState();
}

class _VideoUrlSheetState extends State<_VideoUrlSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BottomGlassSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '网络视频 URL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _GlassTextField(
            label: 'Video URL',
            controller: _controller,
            keyboardType: TextInputType.url,
            placeholder: 'https://example.com/video.mp4',
          ),
          const SizedBox(height: 18),
          _LiquidActionButton(
            label: '载入视频',
            icon: CupertinoIcons.play_rectangle_fill,
            enabled: true,
            onTap: () => Navigator.of(context).pop(_controller.text),
          ),
        ],
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final String placeholder;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.28)),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.09),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.52),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomGlassSheet extends StatelessWidget {
  const _BottomGlassSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, math.max(12, bottom + 12)),
      child: _GlassPanel(
        radius: 38,
        blur: 36,
        tint: Colors.white.withValues(alpha: 0.13),
        borderAlpha: 0.36,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: child,
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: _LiquidSurface(
          radius: 999,
          padding: EdgeInsets.zero,
          tint: Colors.white.withValues(alpha: 0.10),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _LiquidSurface extends StatelessWidget {
  const _LiquidSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 28,
    this.tint,
    this.borderAlpha = 0.22,
    this.blur = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final double borderAlpha;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final baseTint = tint ?? Colors.white.withValues(alpha: 0.095);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: baseTint,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderAlpha),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                baseTint,
                Colors.white.withValues(alpha: 0.035),
              ],
              stops: const [0, 0.46, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.26),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.13),
                blurRadius: 1.2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(child: _GlassSheen(radius: radius)),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassSheen extends StatelessWidget {
  const _GlassSheen({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.34),
                      Colors.white.withValues(alpha: 0.035),
                      Colors.white.withValues(alpha: 0.11),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.22, 0.58, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 1,
              left: 10,
              right: 22,
              height: 1.2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.62),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              bottom: 18,
              left: 1,
              width: 1.1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.30),
                      Colors.transparent,
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
}

class _LiquidOrb extends StatelessWidget {
  const _LiquidOrb({
    required this.size,
    required this.active,
    required this.child,
  });

  final double size;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _LiquidSurface(
      radius: 999,
      padding: EdgeInsets.zero,
      blur: 34,
      tint: Colors.white.withValues(alpha: active ? 0.22 : 0.16),
      borderAlpha: active ? 0.58 : 0.42,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.38, -0.48),
            radius: 0.98,
            colors: active
                ? const [
                    Color(0xFFFFFFFF),
                    Color(0xFFCFF5FF),
                    Color(0xFFB794F6),
                    Color(0xFF60A5FA),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.96),
                    const Color(0xFFDDF7FF).withValues(alpha: 0.88),
                    const Color(0xFFC4B5FD).withValues(alpha: 0.74),
                    const Color(0xFF60A5FA).withValues(alpha: 0.58),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (active ? const Color(0xFF67E8F9) : const Color(0xFF93C5FD))
                      .withValues(alpha: active ? 0.48 : 0.32),
              blurRadius: active ? 52 : 34,
              spreadRadius: active ? 10 : 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: size * 0.16,
              left: size * 0.22,
              child: Container(
                width: size * 0.22,
                height: size * 0.10,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 28,
    this.tint,
    this.borderAlpha = 0.18,
    this.blur = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final double borderAlpha;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return _LiquidSurface(
      radius: radius,
      padding: padding,
      tint: tint ?? Colors.white.withValues(alpha: 0.095),
      borderAlpha: borderAlpha,
      blur: blur,
      child: child,
    );
  }
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Stack(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF08101E),
                    Color(0xFF111827),
                    Color(0xFF17122C),
                    Color(0xFF05070E),
                  ],
                  stops: [0, 0.38, 0.70, 1],
                ),
              ),
              child: SizedBox.expand(),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.28,
                child: CustomPaint(painter: _LiquidMeshPainter(t)),
              ),
            ),
            Positioned(
              top: -92 + 18 * t,
              left: -78 + 10 * t,
              child: _BlurBlob(
                size: 300,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.38),
              ),
            ),
            Positioned(
              top: 116 - 16 * t,
              right: -110 + 22 * t,
              child: _BlurBlob(
                size: 320,
                color: const Color(0xFFC084FC).withValues(alpha: 0.34),
              ),
            ),
            Positioned(
              bottom: -130 + 14 * t,
              left: 28 + 18 * t,
              child: _BlurBlob(
                size: 360,
                color: const Color(0xFF67E8F9).withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              bottom: 130,
              right: -90,
              child: _BlurBlob(
                size: 240,
                color: const Color(0xFF86EFAC).withValues(alpha: 0.12),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BlurBlob extends StatelessWidget {
  const _BlurBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 72, sigmaY: 72),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _LiquidMeshPainter extends CustomPainter {
  const _LiquidMeshPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = Colors.white.withValues(alpha: 0.07);
    const step = 38.0;
    final drift = t * step * 0.35;

    for (double x = -step + drift; x < size.width + step; x += step) {
      final path = Path()..moveTo(x, 0);
      for (double y = 0; y <= size.height; y += step) {
        final wave = math.sin((y / 80) + t * math.pi * 2) * 4;
        path.lineTo(x + wave, y);
      }
      canvas.drawPath(path, linePaint);
    }

    for (double y = -step - drift; y < size.height + step; y += step) {
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += step) {
        final wave = math.cos((x / 88) + t * math.pi * 2) * 3.5;
        path.lineTo(x, y + wave);
      }
      canvas.drawPath(path, linePaint);
    }

    final sparklePaint = Paint()..style = PaintingStyle.fill;
    final points = <Offset>[
      Offset(size.width * 0.18, size.height * (0.20 + 0.03 * t)),
      Offset(size.width * 0.78, size.height * (0.30 - 0.02 * t)),
      Offset(size.width * 0.66, size.height * (0.74 + 0.02 * t)),
      Offset(size.width * 0.30, size.height * (0.86 - 0.02 * t)),
    ];
    for (var i = 0; i < points.length; i++) {
      sparklePaint.color = Colors.white.withValues(alpha: 0.10 - i * 0.012);
      canvas.drawCircle(points[i], 1.8 + i * 0.35, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidMeshPainter oldDelegate) =>
      oldDelegate.t != t;
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
