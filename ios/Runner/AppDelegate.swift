import Flutter
import ActivityKit
import AVFoundation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var translationActivity: Any?
  private let pipController = TranslationPipController()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "ai_voice_translator/live_activity",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "app_delegate_unavailable", message: nil, details: nil))
        return
      }
      switch call.method {
      case "configureAudioSession":
        self.configureAudioSession(result)
      case "start":
        self.startLiveActivity(call.arguments, result: result)
      case "update":
        self.updateLiveActivity(call.arguments, result: result)
      case "end":
        self.endLiveActivity(result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let pipChannel = FlutterMethodChannel(
      name: "ai_voice_translator/pip",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    pipChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "app_delegate_unavailable", message: nil, details: nil))
        return
      }
      switch call.method {
      case "isSupported":
        result(self.pipController.isSupported)
      case "start":
        self.pipController.start(call.arguments, result: result)
      case "update":
        self.pipController.update(call.arguments, result: result)
      case "stop":
        self.pipController.stop(result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureAudioSession(_ result: FlutterResult) {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playAndRecord,
        mode: .default,
        options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
      )
      try session.setActive(true)
      result(true)
    } catch {
      result(
        FlutterError(
          code: "audio_session_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func startLiveActivity(_ rawArguments: Any?, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(false)
      return
    }
    let args = rawArguments as? [String: Any] ?? [:]
    let attributes = TranslationActivityAttributes(
      sourceLanguage: stringValue(args, "sourceLanguage", fallback: "Source"),
      targetLanguage: stringValue(args, "targetLanguage", fallback: "Target")
    )
    let state = activityState(args, fallbackStatus: "视频听译中")

    do {
      if #available(iOS 16.2, *) {
        let content = ActivityContent(
          state: state,
          staleDate: Date().addingTimeInterval(15 * 60)
        )
        translationActivity = try Activity<TranslationActivityAttributes>.request(
          attributes: attributes,
          content: content,
          pushType: nil
        )
      } else {
        translationActivity = try Activity<TranslationActivityAttributes>.request(
          attributes: attributes,
          contentState: state,
          pushType: nil
        )
      }
      result(true)
    } catch {
      result(
        FlutterError(
          code: "live_activity_start_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  private func updateLiveActivity(_ rawArguments: Any?, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(false)
      return
    }
    guard let activity = translationActivity as? Activity<TranslationActivityAttributes> else {
      startLiveActivity(rawArguments, result: result)
      return
    }

    let args = rawArguments as? [String: Any] ?? [:]
    let state = activityState(args, fallbackStatus: "视频听译中")
    Task {
      if #available(iOS 16.2, *) {
        let content = ActivityContent(
          state: state,
          staleDate: Date().addingTimeInterval(15 * 60)
        )
        await activity.update(content)
      } else {
        await activity.update(using: state)
      }
      result(true)
    }
  }

  private func endLiveActivity(_ result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(false)
      return
    }
    guard let activity = translationActivity as? Activity<TranslationActivityAttributes> else {
      result(true)
      return
    }
    translationActivity = nil
    let finalState = TranslationActivityAttributes.ContentState(
      status: "已停止",
      transcript: "",
      translation: ""
    )
    Task {
      if #available(iOS 16.2, *) {
        await activity.end(
          ActivityContent(state: finalState, staleDate: nil),
          dismissalPolicy: .immediate
        )
      } else {
        await activity.end(using: finalState, dismissalPolicy: .immediate)
      }
      result(true)
    }
  }

  @available(iOS 16.1, *)
  private func activityState(
    _ args: [String: Any],
    fallbackStatus: String
  ) -> TranslationActivityAttributes.ContentState {
    TranslationActivityAttributes.ContentState(
      status: stringValue(args, "status", fallback: fallbackStatus),
      transcript: stringValue(args, "transcript", fallback: ""),
      translation: stringValue(args, "translation", fallback: "")
    )
  }

  private func stringValue(
    _ args: [String: Any],
    _ key: String,
    fallback: String
  ) -> String {
    guard let value = args[key] as? String, !value.isEmpty else {
      return fallback
    }
    return value
  }
}
