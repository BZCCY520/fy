import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativePlayerBridge {
  static const MethodChannel _channel = MethodChannel(
    'emby_media_player/native_player',
  );

  /// 初始化原生播放器
  static Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
    } catch (e) {
      debugPrint('Failed to initialize native player: $e');
    }
  }

  /// 播放视频
  ///
  /// [url] 视频 URL
  /// [headers] 可选的 HTTP 请求头
  /// [enableDolby] 是否启用杜比音频处理
  static Future<void> play({
    required String url,
    Map<String, String>? headers,
    bool enableDolby = true,
    double? startPositionSeconds,
  }) async {
    try {
      final arguments = <String, Object?>{
        'url': url,
        'headers': headers ?? {},
        'enableDolby': enableDolby,
      };
      if (startPositionSeconds != null) {
        arguments['startPositionSeconds'] = startPositionSeconds;
      }
      await _channel.invokeMethod('play', arguments);
    } catch (e) {
      debugPrint('Failed to play video: $e');
      rethrow;
    }
  }

  /// 暂停播放
  static Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      debugPrint('Failed to pause: $e');
    }
  }

  /// 恢复播放
  static Future<void> resume() async {
    try {
      await _channel.invokeMethod('resume');
    } catch (e) {
      debugPrint('Failed to resume: $e');
    }
  }

  /// 停止播放
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('Failed to stop: $e');
    }
  }

  /// 跳转到指定位置
  ///
  /// [seconds] 目标时间（秒）
  static Future<void> seekTo(double seconds) async {
    try {
      await _channel.invokeMethod('seekTo', {'seconds': seconds});
    } catch (e) {
      debugPrint('Failed to seek: $e');
    }
  }

  /// 获取当前播放时间（秒）
  static Future<double> getCurrentTime() async {
    try {
      final result = await _channel.invokeMethod('getCurrentTime');
      return (result as num).toDouble();
    } catch (e) {
      debugPrint('Failed to get current time: $e');
      return 0.0;
    }
  }

  /// 获取视频总时长（秒）
  static Future<double> getDuration() async {
    try {
      final result = await _channel.invokeMethod('getDuration');
      return (result as num).toDouble();
    } catch (e) {
      debugPrint('Failed to get duration: $e');
      return 0.0;
    }
  }

  /// 检查是否正在播放
  static Future<bool> isPlaying() async {
    try {
      final result = await _channel.invokeMethod('isPlaying');
      return result as bool;
    } catch (e) {
      debugPrint('Failed to check playing state: $e');
      return false;
    }
  }

  /// 设置播放速率
  ///
  /// [rate] 播放速率（0.5 - 2.0）
  static Future<void> setPlaybackRate(double rate) async {
    try {
      await _channel.invokeMethod('setPlaybackRate', {'rate': rate});
    } catch (e) {
      debugPrint('Failed to set playback rate: $e');
    }
  }

  /// 设置音量
  ///
  /// [volume] 音量（0.0 - 1.0）
  static Future<void> setVolume(double volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } catch (e) {
      debugPrint('Failed to set volume: $e');
    }
  }

  /// 检查是否支持杜比音频
  static Future<bool> isDolbySupported() async {
    try {
      final result = await _channel.invokeMethod('isDolbySupported');
      return result as bool;
    } catch (e) {
      debugPrint('Failed to check Dolby support: $e');
      return false;
    }
  }

  /// 获取音频轨道信息
  static Future<List<Map<String, dynamic>>> getAudioTracks() async {
    try {
      final result = await _channel.invokeMethod('getAudioTracks');
      return _trackListFromResult(result);
    } catch (e) {
      debugPrint('Failed to get audio tracks: $e');
      return [];
    }
  }

  /// 选择音频轨道
  ///
  /// [trackIndex] 音轨索引
  static Future<void> selectAudioTrack(int trackIndex) async {
    try {
      await _channel.invokeMethod('selectAudioTrack', {
        'trackIndex': trackIndex,
      });
    } catch (e) {
      debugPrint('Failed to select audio track: $e');
    }
  }

  /// 获取字幕轨道信息
  static Future<List<Map<String, dynamic>>> getSubtitleTracks() async {
    try {
      final result = await _channel.invokeMethod('getSubtitleTracks');
      return _trackListFromResult(result);
    } catch (e) {
      debugPrint('Failed to get subtitle tracks: $e');
      return [];
    }
  }

  /// 选择字幕轨道
  ///
  /// [trackIndex] 字幕轨道索引；传入 -1 表示关闭字幕。
  static Future<void> selectSubtitleTrack(int trackIndex) async {
    try {
      await _channel.invokeMethod('selectSubtitleTrack', {
        'trackIndex': trackIndex,
      });
    } catch (e) {
      debugPrint('Failed to select subtitle track: $e');
    }
  }

  static List<Map<String, dynamic>> _trackListFromResult(Object? result) {
    if (result is! List) {
      return [];
    }

    return result
        .whereType<Map>()
        .map((track) => Map<String, dynamic>.from(track))
        .toList(growable: false);
  }

  /// 设置播放器回调
  static void setMethodCallHandler(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {
    _channel.setMethodCallHandler(handler);
  }
}
