import AVFoundation
import AVKit
import Flutter
import UIKit

final class TranslationPipController: NSObject, AVPictureInPictureControllerDelegate {
  private var sourceView: UIView?
  private var contentViewController: AVPictureInPictureVideoCallViewController?
  private var contentView: TranslationPipView?
  private var pipController: AVPictureInPictureController?

  var isSupported: Bool {
    AVPictureInPictureController.isPictureInPictureSupported()
  }

  func start(_ rawArguments: Any?, result: @escaping FlutterResult) {
    guard isSupported else {
      result(false)
      return
    }

    do {
      try ensurePipeline()
      apply(rawArguments)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
        guard let self = self, let pipController = self.pipController else {
          return
        }
        if !pipController.isPictureInPictureActive {
          pipController.startPictureInPicture()
        }
      }
      result(true)
    } catch {
      result(
        FlutterError(
          code: "pip_start_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  func update(_ rawArguments: Any?, result: @escaping FlutterResult) {
    apply(rawArguments)
    result(true)
  }

  func stop(_ result: @escaping FlutterResult) {
    if let pipController = pipController, pipController.isPictureInPictureActive {
      pipController.stopPictureInPicture()
    }
    result(true)
  }

  private func ensurePipeline() throws {
    if pipController != nil {
      return
    }

    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap({ $0.windows })
      .first(where: { $0.isKeyWindow })
    else {
      throw NSError(
        domain: "ai_voice_translator.pip",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "无法找到当前 iOS 窗口，画中画暂不可用。"]
      )
    }

    let sourceView = UIView(frame: CGRect(x: 1, y: 1, width: 2, height: 2))
    sourceView.backgroundColor = .clear
    sourceView.alpha = 0.01
    sourceView.isUserInteractionEnabled = false
    window.addSubview(sourceView)
    self.sourceView = sourceView

    let contentViewController = AVPictureInPictureVideoCallViewController()
    contentViewController.preferredContentSize = CGSize(width: 640, height: 360)
    contentViewController.view.backgroundColor = .clear
    self.contentViewController = contentViewController

    let contentView = TranslationPipView()
    contentView.translatesAutoresizingMaskIntoConstraints = false
    contentViewController.view.addSubview(contentView)
    NSLayoutConstraint.activate([
      contentView.leadingAnchor.constraint(equalTo: contentViewController.view.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: contentViewController.view.trailingAnchor),
      contentView.topAnchor.constraint(equalTo: contentViewController.view.topAnchor),
      contentView.bottomAnchor.constraint(equalTo: contentViewController.view.bottomAnchor),
    ])
    self.contentView = contentView

    let source = AVPictureInPictureController.ContentSource(
      activeVideoCallSourceView: sourceView,
      contentViewController: contentViewController
    )
    let pipController = AVPictureInPictureController(contentSource: source)
    pipController.delegate = self
    pipController.canStartPictureInPictureAutomaticallyFromInline = true
    pipController.requiresLinearPlayback = true
    self.pipController = pipController
  }

  private func apply(_ rawArguments: Any?) {
    let args = rawArguments as? [String: Any] ?? [:]
    let state = TranslationPipState(
      sourceLanguage: stringValue(args, "sourceLanguage", fallback: "Source"),
      targetLanguage: stringValue(args, "targetLanguage", fallback: "Target"),
      status: stringValue(args, "status", fallback: "声译 AI"),
      transcript: stringValue(args, "transcript", fallback: ""),
      translation: stringValue(args, "translation", fallback: "")
    )
    contentView?.state = state
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

private struct TranslationPipState {
  var sourceLanguage: String = "Source"
  var targetLanguage: String = "Target"
  var status: String = "声译 AI"
  var transcript: String = ""
  var translation: String = ""
}

private final class TranslationPipView: UIView {
  var state = TranslationPipState() {
    didSet { applyState(animated: true) }
  }

  private let backgroundGradient = CAGradientLayer()
  private let cyanBlob = CALayer()
  private let purpleBlob = CALayer()
  private let glassView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
  private let statusLabel = UILabel()
  private let languageLabel = UILabel()
  private let primaryLabel = UILabel()
  private let secondaryLabel = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    backgroundGradient.frame = bounds
    cyanBlob.frame = CGRect(x: -70, y: -44, width: 220, height: 220)
    cyanBlob.cornerRadius = 110
    purpleBlob.frame = CGRect(x: bounds.width - 170, y: 20, width: 240, height: 240)
    purpleBlob.cornerRadius = 120
    glassView.layer.cornerRadius = 34
  }

  private func setup() {
    clipsToBounds = true

    backgroundGradient.colors = [
      UIColor(red: 0.03, green: 0.06, blue: 0.12, alpha: 1).cgColor,
      UIColor(red: 0.08, green: 0.10, blue: 0.22, alpha: 1).cgColor,
      UIColor(red: 0.02, green: 0.03, blue: 0.07, alpha: 1).cgColor,
    ]
    backgroundGradient.locations = [0, 0.58, 1]
    backgroundGradient.startPoint = CGPoint(x: 0, y: 0)
    backgroundGradient.endPoint = CGPoint(x: 1, y: 1)
    layer.addSublayer(backgroundGradient)

    cyanBlob.backgroundColor = UIColor(red: 0.22, green: 0.83, blue: 1, alpha: 0.32).cgColor
    cyanBlob.shadowColor = UIColor(red: 0.22, green: 0.83, blue: 1, alpha: 0.65).cgColor
    cyanBlob.shadowOpacity = 1
    cyanBlob.shadowRadius = 50
    layer.addSublayer(cyanBlob)

    purpleBlob.backgroundColor = UIColor(red: 0.75, green: 0.52, blue: 1, alpha: 0.26).cgColor
    purpleBlob.shadowColor = UIColor(red: 0.75, green: 0.52, blue: 1, alpha: 0.55).cgColor
    purpleBlob.shadowOpacity = 1
    purpleBlob.shadowRadius = 56
    layer.addSublayer(purpleBlob)

    glassView.translatesAutoresizingMaskIntoConstraints = false
    glassView.clipsToBounds = true
    glassView.layer.cornerRadius = 34
    glassView.layer.borderWidth = 1.2
    glassView.layer.borderColor = UIColor.white.withAlphaComponent(0.32).cgColor
    addSubview(glassView)
    NSLayoutConstraint.activate([
      glassView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 34),
      glassView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -34),
      glassView.topAnchor.constraint(equalTo: topAnchor, constant: 34),
      glassView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -34),
    ])

    let stack = UIStackView(arrangedSubviews: [
      statusLabel,
      languageLabel,
      primaryLabel,
      secondaryLabel,
    ])
    stack.axis = .vertical
    stack.spacing = 8
    stack.alignment = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false
    glassView.contentView.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -24),
      stack.topAnchor.constraint(equalTo: glassView.contentView.topAnchor, constant: 20),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: glassView.contentView.bottomAnchor, constant: -20),
    ])

    statusLabel.font = .systemFont(ofSize: 20, weight: .black)
    statusLabel.textColor = UIColor.white.withAlphaComponent(0.78)

    languageLabel.font = .systemFont(ofSize: 15, weight: .bold)
    languageLabel.textColor = UIColor.white.withAlphaComponent(0.56)

    primaryLabel.font = .systemFont(ofSize: 34, weight: .black)
    primaryLabel.textColor = .white
    primaryLabel.numberOfLines = 3
    primaryLabel.adjustsFontSizeToFitWidth = true
    primaryLabel.minimumScaleFactor = 0.72

    secondaryLabel.font = .systemFont(ofSize: 18, weight: .semibold)
    secondaryLabel.textColor = UIColor.white.withAlphaComponent(0.60)
    secondaryLabel.numberOfLines = 2

    applyState(animated: false)
    startAmbientAnimation()
  }

  private func applyState(animated: Bool) {
    let translation = state.translation.trimmingCharacters(in: .whitespacesAndNewlines)
    let transcript = state.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    let primary = translation.isEmpty
      ? (transcript.isEmpty ? "等待识别与翻译…" : transcript)
      : translation
    let secondary = translation.isEmpty ? "" : transcript

    let updates = {
      self.statusLabel.text = self.state.status
      self.languageLabel.text = "\(self.state.sourceLanguage) → \(self.state.targetLanguage)"
      self.primaryLabel.text = primary
      self.secondaryLabel.text = secondary
      self.secondaryLabel.isHidden = secondary.isEmpty
    }

    if animated {
      UIView.transition(
        with: self.primaryLabel,
        duration: 0.22,
        options: .transitionCrossDissolve,
        animations: updates
      )
    } else {
      updates()
    }
  }

  private func startAmbientAnimation() {
    let cyan = CABasicAnimation(keyPath: "transform.translation.x")
    cyan.fromValue = -10
    cyan.toValue = 18
    cyan.duration = 4.6
    cyan.autoreverses = true
    cyan.repeatCount = .infinity
    cyan.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    cyanBlob.add(cyan, forKey: "cyan-drift")

    let purple = CABasicAnimation(keyPath: "transform.translation.y")
    purple.fromValue = 14
    purple.toValue = -18
    purple.duration = 5.2
    purple.autoreverses = true
    purple.repeatCount = .infinity
    purple.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    purpleBlob.add(purple, forKey: "purple-drift")
  }
}
