import Flutter
import AVFoundation
import AVKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let nativePlayerController = NativePlayerController()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let nativePlayerChannel = FlutterMethodChannel(
      name: "emby_media_player/native_player",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    nativePlayerChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "app_delegate_unavailable", message: nil, details: nil))
        return
      }
      self.nativePlayerController.handle(call, result: result)
    }
  }
}

private final class NativePlayerController: NSObject {
  private var player: AVPlayer?
  private var playerViewController: AVPlayerViewController?
  private var preferredRate: Float = 1.0

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      initialize(result)
    case "play":
      play(call.arguments, result: result)
    case "pause":
      player?.pause()
      result(true)
    case "resume":
      if let player {
        player.rate = preferredRate
      }
      result(true)
    case "stop":
      DispatchQueue.main.async { [weak self] in
        self?.stopPlayback(animated: true) {
          result(true)
        }
      }
    case "seekTo":
      seekTo(call.arguments, result: result)
    case "getCurrentTime":
      result(seconds(from: player?.currentTime()))
    case "getDuration":
      result(seconds(from: player?.currentItem?.duration))
    case "isPlaying":
      result((player?.rate ?? 0) > 0)
    case "setPlaybackRate":
      setPlaybackRate(call.arguments, result: result)
    case "setVolume":
      setVolume(call.arguments, result: result)
    case "isDolbySupported":
      result(true)
    case "getAudioTracks":
      result(audioTracks())
    case "selectAudioTrack":
      selectAudioTrack(call.arguments, result: result)
    case "getSubtitleTracks":
      result(subtitleTracks())
    case "selectSubtitleTrack":
      selectSubtitleTrack(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initialize(_ result: FlutterResult) {
    do {
      try configurePlaybackAudioSession()
      result(true)
    } catch {
      result(
        FlutterError(
          code: "native_player_init_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func play(_ rawArguments: Any?, result: @escaping FlutterResult) {
    let args = rawArguments as? [String: Any] ?? [:]
    guard let urlString = args["url"] as? String,
          let url = URL(string: urlString),
          !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(
        FlutterError(
          code: "invalid_url",
          message: "缺少或无法识别视频 URL。",
          details: nil
        )
      )
      return
    }

    let headers = args["headers"] as? [String: String] ?? [:]
    let startPositionSeconds = doubleValue(args["startPositionSeconds"], fallback: 0)

    DispatchQueue.main.async { [weak self] in
      guard let self else {
        result(FlutterError(code: "native_player_unavailable", message: nil, details: nil))
        return
      }

      do {
        try self.configurePlaybackAudioSession()
      } catch {
        result(
          FlutterError(
            code: "audio_session_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
        return
      }

      guard let presenter = self.topViewController() else {
        result(
          FlutterError(
            code: "presenter_not_found",
            message: "无法找到当前界面来展示播放器。",
            details: nil
          )
        )
        return
      }

      self.stopPlayback(animated: false) {
        let assetOptions: [String: Any] = headers.isEmpty
          ? [:]
          : ["AVURLAssetHTTPHeaderFieldsKey": headers]
        let asset = AVURLAsset(url: url, options: assetOptions)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true

        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.modalPresentationStyle = .fullScreen
        playerViewController.allowsPictureInPicturePlayback =
          AVPictureInPictureController.isPictureInPictureSupported()
        if #available(iOS 14.2, *) {
          playerViewController.canStartPictureInPictureAutomaticallyFromInline = true
        }

        self.player = player
        self.playerViewController = playerViewController
        self.preferredRate = 1.0

        presenter.present(playerViewController, animated: true) {
          let startPlayback = {
            player.play()
            result(true)
          }
          if startPositionSeconds > 0 {
            let startTime = CMTime(seconds: startPositionSeconds, preferredTimescale: 600)
            player.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
              startPlayback()
            }
          } else {
            startPlayback()
          }
        }
      }
    }
  }

  private func seekTo(_ rawArguments: Any?, result: @escaping FlutterResult) {
    let args = rawArguments as? [String: Any] ?? [:]
    let targetSeconds = doubleValue(args["seconds"], fallback: 0)
    let time = CMTime(seconds: targetSeconds, preferredTimescale: 600)
    player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
      result(finished)
    }
  }

  private func setPlaybackRate(_ rawArguments: Any?, result: FlutterResult) {
    let args = rawArguments as? [String: Any] ?? [:]
    let requestedRate = Float(doubleValue(args["rate"], fallback: 1.0))
    let clampedRate = min(max(requestedRate, 0.5), 2.0)
    preferredRate = clampedRate
    if let player, player.rate > 0 {
      player.rate = clampedRate
    }
    result(true)
  }

  private func setVolume(_ rawArguments: Any?, result: FlutterResult) {
    let args = rawArguments as? [String: Any] ?? [:]
    let requestedVolume = Float(doubleValue(args["volume"], fallback: 1.0))
    player?.volume = min(max(requestedVolume, 0.0), 1.0)
    result(true)
  }

  private func mediaTracks(
    for characteristic: AVMediaCharacteristic,
    includeOffOption: Bool = false
  ) -> [[String: Any]] {
    guard let item = player?.currentItem,
          let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic)
    else {
      return []
    }

    let selectedOption = item.currentMediaSelection.selectedMediaOption(in: group)
    var tracks: [[String: Any]] = []

    if includeOffOption {
      tracks.append([
        "index": -1,
        "id": "off",
        "displayName": "关闭字幕",
        "languageCode": "",
        "isSelected": selectedOption == nil,
        "isOff": true,
      ])
    }

    tracks.append(
      contentsOf: group.options.enumerated().map { index, option in
        [
          "index": index,
          "id": String(describing: option.propertyList()),
          "displayName": option.displayName,
          "languageCode": option.extendedLanguageTag ?? option.locale?.identifier ?? "",
          "isSelected": selectedOption == option,
          "isOff": false,
        ]
      }
    )

    return tracks
  }

  private func audioTracks() -> [[String: Any]] {
    mediaTracks(for: .audible)
  }

  private func subtitleTracks() -> [[String: Any]] {
    mediaTracks(for: .legible, includeOffOption: true)
  }

  private func selectAudioTrack(_ rawArguments: Any?, result: FlutterResult) {
    selectMediaTrack(
      rawArguments,
      characteristic: .audible,
      allowEmptySelection: false,
      errorCode: "audio_track_not_found",
      errorMessage: "无法找到指定音轨。",
      result: result
    )
  }

  private func selectSubtitleTrack(_ rawArguments: Any?, result: FlutterResult) {
    selectMediaTrack(
      rawArguments,
      characteristic: .legible,
      allowEmptySelection: true,
      errorCode: "subtitle_track_not_found",
      errorMessage: "无法找到指定字幕轨道。",
      result: result
    )
  }

  private func selectMediaTrack(
    _ rawArguments: Any?,
    characteristic: AVMediaCharacteristic,
    allowEmptySelection: Bool,
    errorCode: String,
    errorMessage: String,
    result: FlutterResult
  ) {
    let args = rawArguments as? [String: Any] ?? [:]
    let trackIndex = intValue(args["trackIndex"], fallback: -1)
    guard let item = player?.currentItem,
          let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: characteristic)
    else {
      result(
        FlutterError(
          code: errorCode,
          message: errorMessage,
          details: nil
        )
      )
      return
    }

    if trackIndex < 0, allowEmptySelection {
      item.select(nil, in: group)
      result(true)
      return
    }

    guard group.options.indices.contains(trackIndex) else {
      result(
        FlutterError(
          code: errorCode,
          message: errorMessage,
          details: nil
        )
      )
      return
    }

    item.select(group.options[trackIndex], in: group)
    result(true)
  }

  private func stopPlayback(animated: Bool, completion: @escaping () -> Void) {
    player?.pause()

    guard let playerViewController else {
      player = nil
      completion()
      return
    }

    let cleanup = { [weak self] in
      self?.player = nil
      self?.playerViewController = nil
      completion()
    }

    if playerViewController.presentingViewController != nil {
      playerViewController.dismiss(animated: animated, completion: cleanup)
    } else {
      cleanup()
    }
  }

  private func configurePlaybackAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playback,
      mode: .moviePlayback,
      options: [.allowAirPlay, .allowBluetoothA2DP]
    )
    try session.setActive(true)
  }

  private func topViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController
    return topViewController(from: root)
  }

  private func topViewController(from controller: UIViewController?) -> UIViewController? {
    if let navigationController = controller as? UINavigationController {
      return topViewController(from: navigationController.visibleViewController)
    }
    if let tabBarController = controller as? UITabBarController {
      return topViewController(from: tabBarController.selectedViewController)
    }
    if let presented = controller?.presentedViewController {
      return topViewController(from: presented)
    }
    return controller
  }

  private func doubleValue(_ rawValue: Any?, fallback: Double) -> Double {
    if let value = rawValue as? Double {
      return value
    }
    if let value = rawValue as? NSNumber {
      return value.doubleValue
    }
    if let value = rawValue as? String, let parsed = Double(value) {
      return parsed
    }
    return fallback
  }

  private func intValue(_ rawValue: Any?, fallback: Int) -> Int {
    if let value = rawValue as? Int {
      return value
    }
    if let value = rawValue as? NSNumber {
      return value.intValue
    }
    if let value = rawValue as? String, let parsed = Int(value) {
      return parsed
    }
    return fallback
  }

  private func seconds(from time: CMTime?) -> Double {
    guard let time, time.isNumeric else {
      return 0
    }
    let value = CMTimeGetSeconds(time)
    return value.isFinite ? value : 0
  }
}
