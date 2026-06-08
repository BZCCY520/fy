import AVFoundation
import AVKit
import CoreMedia
import CoreVideo
import Flutter
import UIKit

final class TranslationPipController: NSObject,
  AVPictureInPictureControllerDelegate,
  AVPictureInPictureSampleBufferPlaybackDelegate
{
  private let renderSize = CGSize(width: 640, height: 360)
  private var hostView: UIView?
  private var displayLayer: AVSampleBufferDisplayLayer?
  private var pipController: AVPictureInPictureController?
  private var displayLink: CADisplayLink?
  private var frameRenderer = TranslationFrameRenderer(size: CGSize(width: 640, height: 360))
  private var timebase: CMTimebase?
  private var frameIndex: Int64 = 0
  private var isRunning = false
  private var isPaused = false

  var isSupported: Bool {
    AVPictureInPictureController.isPictureInPictureSupported()
  }

  func start(_ rawArguments: Any?, result: @escaping FlutterResult) {
    guard isSupported else {
      result(false)
      return
    }
    ensurePipeline()
    update(rawArguments, result: { _ in })
    isRunning = true
    isPaused = false
    displayLink?.isPaused = false
    if let timebase {
      CMTimebaseSetRate(timebase, rate: 1)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
      guard let self, let pipController = self.pipController else {
        return
      }
      if !pipController.isPictureInPictureActive {
        pipController.startPictureInPicture()
      }
    }
    result(true)
  }

  func update(_ rawArguments: Any?, result: @escaping FlutterResult) {
    let args = rawArguments as? [String: Any] ?? [:]
    frameRenderer.state = TranslationPipState(
      sourceLanguage: stringValue(args, "sourceLanguage", fallback: "Source"),
      targetLanguage: stringValue(args, "targetLanguage", fallback: "Target"),
      status: stringValue(args, "status", fallback: "声译 AI"),
      transcript: stringValue(args, "transcript", fallback: ""),
      translation: stringValue(args, "translation", fallback: "")
    )
    enqueueFrame(displayImmediately: true)
    result(true)
  }

  func stop(_ result: @escaping FlutterResult) {
    isRunning = false
    isPaused = true
    displayLink?.isPaused = true
    if let timebase {
      CMTimebaseSetRate(timebase, rate: 0)
    }
    if let pipController, pipController.isPictureInPictureActive {
      pipController.stopPictureInPicture()
    }
    result(true)
  }

  private func ensurePipeline() {
    if pipController != nil {
      return
    }

    let hostView = UIView(frame: CGRect(origin: .zero, size: renderSize))
    hostView.backgroundColor = .clear
    hostView.isUserInteractionEnabled = false

    let keyWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    keyWindow?.insertSubview(hostView, at: 0)
    self.hostView = hostView

    let displayLayer = AVSampleBufferDisplayLayer()
    displayLayer.frame = hostView.bounds
    displayLayer.videoGravity = .resizeAspect
    hostView.layer.addSublayer(displayLayer)
    self.displayLayer = displayLayer

    var controlTimebase: CMTimebase?
    CMTimebaseCreateWithSourceClock(
      allocator: kCFAllocatorDefault,
      sourceClock: CMClockGetHostTimeClock(),
      timebaseOut: &controlTimebase
    )
    timebase = controlTimebase
    if let controlTimebase {
      CMTimebaseSetTime(controlTimebase, time: .zero)
      CMTimebaseSetRate(controlTimebase, rate: 1)
      displayLayer.controlTimebase = controlTimebase
    }

    let source = AVPictureInPictureController.ContentSource(
      sampleBufferDisplayLayer: displayLayer,
      playbackDelegate: self
    )
    let pipController = AVPictureInPictureController(contentSource: source)
    pipController.delegate = self
    pipController.canStartPictureInPictureAutomaticallyFromInline = true
    pipController.requiresLinearPlayback = true
    self.pipController = pipController

    displayLink = CADisplayLink(target: self, selector: #selector(displayTick))
    displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 1, maximum: 8, preferred: 4)
    displayLink?.isPaused = true
    displayLink?.add(to: .main, forMode: .common)
  }

  @objc private func displayTick() {
    guard isRunning, !isPaused else {
      return
    }
    enqueueFrame(displayImmediately: false)
  }

  private func enqueueFrame(displayImmediately: Bool) {
    guard let displayLayer else {
      return
    }
    if displayLayer.status == .failed {
      displayLayer.flush()
    }
    guard displayLayer.isReadyForMoreMediaData else {
      return
    }
    guard let image = frameRenderer.render(),
      let sampleBuffer = makeSampleBuffer(from: image, displayImmediately: displayImmediately)
    else {
      return
    }
    displayLayer.enqueue(sampleBuffer)
    frameIndex += 1
  }

  private func makeSampleBuffer(from image: UIImage, displayImmediately: Bool) -> CMSampleBuffer? {
    guard let pixelBuffer = makePixelBuffer(from: image) else {
      return nil
    }

    var formatDescription: CMVideoFormatDescription?
    let descriptionStatus = CMVideoFormatDescriptionCreateForImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: pixelBuffer,
      formatDescriptionOut: &formatDescription
    )
    guard descriptionStatus == noErr, let formatDescription else {
      return nil
    }

    var timing = CMSampleTimingInfo(
      duration: CMTime(value: 1, timescale: 4),
      presentationTimeStamp: CMTime(value: frameIndex, timescale: 4),
      decodeTimeStamp: .invalid
    )
    var sampleBuffer: CMSampleBuffer?
    let bufferStatus = CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: pixelBuffer,
      formatDescription: formatDescription,
      sampleTiming: &timing,
      sampleBufferOut: &sampleBuffer
    )
    guard bufferStatus == noErr, let sampleBuffer else {
      return nil
    }

    if displayImmediately,
      let attachments = CMSampleBufferGetSampleAttachmentsArray(
        sampleBuffer,
        createIfNecessary: true
      )
    {
      let attachment = unsafeBitCast(
        CFArrayGetValueAtIndex(attachments, 0),
        to: CFMutableDictionary.self
      )
      CFDictionarySetValue(
        attachment,
        Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
        Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
      )
    }
    return sampleBuffer
  }

  private func makePixelBuffer(from image: UIImage) -> CVPixelBuffer? {
    let width = Int(renderSize.width)
    let height = Int(renderSize.height)
    let attributes = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true,
      kCVPixelBufferIOSurfacePropertiesKey: [:],
    ] as CFDictionary

    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
      kCFAllocatorDefault,
      width,
      height,
      kCVPixelFormatType_32BGRA,
      attributes,
      &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pixelBuffer else {
      return nil
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    guard let context = CGContext(
      data: CVPixelBufferGetBaseAddress(pixelBuffer),
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        | CGBitmapInfo.byteOrder32Little.rawValue
    ) else {
      return nil
    }

    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    UIGraphicsPushContext(context)
    image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
    UIGraphicsPopContext()
    return pixelBuffer
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    setPlaying playing: Bool
  ) {
    isPaused = !playing
    displayLink?.isPaused = !playing
    if let timebase {
      CMTimebaseSetRate(timebase, rate: playing ? 1 : 0)
    }
  }

  func pictureInPictureControllerTimeRangeForPlayback(
    _ pictureInPictureController: AVPictureInPictureController
  ) -> CMTimeRange {
    CMTimeRange(start: .zero, duration: CMTime(seconds: 24 * 60 * 60, preferredTimescale: 600))
  }

  func pictureInPictureControllerIsPlaybackPaused(
    _ pictureInPictureController: AVPictureInPictureController
  ) -> Bool {
    isPaused
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    didTransitionToRenderSize newRenderSize: CMVideoDimensions
  ) {
    enqueueFrame(displayImmediately: true)
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    skipByInterval skipInterval: CMTime,
    completion completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }

  func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(
    _ pictureInPictureController: AVPictureInPictureController
  ) -> Bool {
    true
  }

  func pictureInPictureControllerDidStopPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    isRunning = false
    isPaused = true
    displayLink?.isPaused = true
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

private final class TranslationFrameRenderer {
  let size: CGSize
  var state = TranslationPipState()

  init(size: CGSize) {
    self.size = size
  }

  func render() -> UIImage? {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { context in
      draw(in: CGRect(origin: .zero, size: size), context: context.cgContext)
    }
  }

  private func draw(in rect: CGRect, context: CGContext) {
    let colors = [
      UIColor(red: 0.03, green: 0.06, blue: 0.12, alpha: 1).cgColor,
      UIColor(red: 0.08, green: 0.10, blue: 0.22, alpha: 1).cgColor,
      UIColor(red: 0.02, green: 0.03, blue: 0.07, alpha: 1).cgColor,
    ] as CFArray
    if let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: colors,
      locations: [0, 0.58, 1]
    ) {
      context.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX, y: rect.minY),
        end: CGPoint(x: rect.maxX, y: rect.maxY),
        options: []
      )
    }

    drawBlob(
      center: CGPoint(x: rect.width * 0.18, y: rect.height * 0.16),
      radius: 160,
      color: UIColor(red: 0.22, green: 0.83, blue: 1, alpha: 0.30),
      context: context
    )
    drawBlob(
      center: CGPoint(x: rect.width * 0.86, y: rect.height * 0.25),
      radius: 190,
      color: UIColor(red: 0.75, green: 0.52, blue: 1, alpha: 0.24),
      context: context
    )

    let glassRect = rect.insetBy(dx: 34, dy: 34)
    let path = UIBezierPath(roundedRect: glassRect, cornerRadius: 34)
    UIColor.white.withAlphaComponent(0.14).setFill()
    path.fill()
    UIColor.white.withAlphaComponent(0.35).setStroke()
    path.lineWidth = 1.4
    path.stroke()

    NSString(string: state.status).draw(
      at: CGPoint(x: glassRect.minX + 24, y: glassRect.minY + 20),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 20, weight: .black),
        .foregroundColor: UIColor.white.withAlphaComponent(0.78),
      ]
    )

    NSString(string: "\(state.sourceLanguage) → \(state.targetLanguage)").draw(
      at: CGPoint(x: glassRect.minX + 24, y: glassRect.minY + 50),
      withAttributes: [
        .font: UIFont.systemFont(ofSize: 15, weight: .bold),
        .foregroundColor: UIColor.white.withAlphaComponent(0.55),
      ]
    )

    let translation = state.translation.trimmingCharacters(in: .whitespacesAndNewlines)
    let transcript = state.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    let primary = translation.isEmpty ? (transcript.isEmpty ? "等待识别与翻译…" : transcript) : translation
    let secondary = translation.isEmpty ? "" : transcript

    drawText(
      primary,
      rect: CGRect(
        x: glassRect.minX + 24,
        y: glassRect.minY + 102,
        width: glassRect.width - 48,
        height: 104
      ),
      font: UIFont.systemFont(ofSize: 34, weight: .black),
      color: .white
    )

    if !secondary.isEmpty {
      drawText(
        secondary,
        rect: CGRect(
          x: glassRect.minX + 24,
          y: glassRect.minY + 218,
          width: glassRect.width - 48,
          height: 58
        ),
        font: UIFont.systemFont(ofSize: 18, weight: .semibold),
        color: UIColor.white.withAlphaComponent(0.58)
      )
    }
  }

  private func drawBlob(
    center: CGPoint,
    radius: CGFloat,
    color: UIColor,
    context: CGContext
  ) {
    context.saveGState()
    context.setShadow(offset: .zero, blur: 46, color: color.cgColor)
    context.setFillColor(color.cgColor)
    context.fillEllipse(
      in: CGRect(
        x: center.x - radius / 2,
        y: center.y - radius / 2,
        width: radius,
        height: radius
      )
    )
    context.restoreGState()
  }

  private func drawText(
    _ text: String,
    rect: CGRect,
    font: UIFont,
    color: UIColor
  ) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byTruncatingTail
    paragraph.alignment = .left
    paragraph.lineSpacing = 2
    NSString(string: text).draw(
      with: rect,
      options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
      attributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph,
      ],
      context: nil
    )
  }
}
