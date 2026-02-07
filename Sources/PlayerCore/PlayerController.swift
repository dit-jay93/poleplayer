@preconcurrency import AVFoundation
import Combine
import CoreImage
import CoreMedia
import CoreVideo
import Foundation
import os
import DecodeKit

public enum PlaybackMode: String {
    case realTime = "REAL-TIME"
    case precision = "PRECISION"
}

public enum PlaybackState: String {
    case stopped
    case paused
    case playing
}

public enum PrecisionTrigger: String {
    case none
    case step
    case seek
    case annotate
    case exportStill
}

public enum PlayerCoreError: LocalizedError {
    case assetNotPlayable
    case noVideoTrack
    case failedToLoad(String)

    public var errorDescription: String? {
        switch self {
        case .assetNotPlayable:
            return "Asset is not playable."
        case .noVideoTrack:
            return "No video track found in asset."
        case .failedToLoad(let reason):
            return "Failed to load asset: \(reason)"
        }
    }
}

private enum CaptureError: LocalizedError {
    case noFrame

    var errorDescription: String? {
        switch self {
        case .noFrame:
            return "Unable to capture frame."
        }
    }
}

@MainActor
public final class PlayerController: ObservableObject {
    public let player: AVPlayer

    @Published public private(set) var mode: PlaybackMode = .realTime
    @Published public private(set) var state: PlaybackState = .stopped
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var playbackRate: Float = 0
    @Published public private(set) var frameIndex: Int = 0
    @Published public private(set) var fps: Double = 0
    @Published public private(set) var resolution: CGSize = .zero
    @Published public private(set) var timecode: String = "00:00:00:00"
    @Published public private(set) var durationFrames: Int = 0
    @Published public private(set) var currentTimeSeconds: Double = 0
    @Published public private(set) var hasVideo: Bool = false
    @Published public private(set) var lastErrorMessage: String? = nil
    @Published public private(set) var debugVideoFrames: Int = 0
    @Published public private(set) var debugLastFrameAt: Double = 0
    @Published public private(set) var debugFrameSize: CGSize = .zero
    @Published public private(set) var debugFrameSource: String = "none"
    @Published public private(set) var debugRenderTicks: Int = 0
    @Published public private(set) var debugLastRenderAt: Double = 0
    @Published public private(set) var debugLastPrecisionSource: String = "—"
    @Published public private(set) var debugLastPrecisionAt: Double = 0
    @Published public private(set) var precisionTrigger: PrecisionTrigger = .none
    @Published public private(set) var isLooping: Bool = false
    @Published public private(set) var inPointFrame: Int? = nil
    @Published public private(set) var outPointFrame: Int? = nil

    private let log = Logger(subsystem: "PolePlayer", category: "PlayerCore")
    private var timeObserverToken: Any?
    private var endObserver: NSObjectProtocol?
    private var reverseTimer: Timer?
    private var asset: AVAsset?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var assetReaderSource: AssetReaderFrameSource?
    private var precisionDecoder: DecoderPlugin?
    private let imageGenQueue = DispatchQueue(label: "PlayerCore.ImageGenerator")
    private var loopSeekInFlight: Bool = false
    private var timecodeStartFrames: Int = 0

    private let preferredTimeScale: CMTimeScale = 600

    public init() {
        self.player = AVPlayer()
        self.player.actionAtItemEnd = .pause
    }

    public func clear() {
        stopReverseTimer()
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        player.replaceCurrentItem(with: nil)
        asset = nil
        videoOutput = nil
        assetReaderSource?.stop()
        assetReaderSource = nil
        precisionDecoder = nil
        timeObserverToken = nil
        endObserver = nil
        hasVideo = false
        fps = 0
        resolution = .zero
        timecode = "00:00:00:00"
        durationFrames = 0
        frameIndex = 0
        currentTimeSeconds = 0
        isPlaying = false
        playbackRate = 0
        mode = .realTime
        state = .stopped
        lastErrorMessage = nil
        debugVideoFrames = 0
        debugLastFrameAt = 0
        debugFrameSize = .zero
        debugFrameSource = "none"
        debugRenderTicks = 0
        debugLastRenderAt = 0
        debugLastPrecisionSource = "—"
        debugLastPrecisionAt = 0
        precisionTrigger = .none
        isLooping = false
        inPointFrame = nil
        outPointFrame = nil
        loopSeekInFlight = false
        timecodeStartFrames = 0
    }

    public func openVideo(url: URL) {
        clear()
        log.info("Opening video: \(url.path, privacy: .public)")
        let asset = AVURLAsset(url: url)
        self.asset = asset
        Task { [weak self] in
            await self?.finishLoading(asset: asset)
        }
    }

    private func finishLoading(asset: AVAsset) async {
        do {
            let playable = try await asset.load(.isPlayable)
            guard playable else {
                handleError(PlayerCoreError.assetNotPlayable)
                return
            }

            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                handleError(PlayerCoreError.noVideoTrack)
                return
            }

            let nominalFPS = try await track.load(.nominalFrameRate)
            fps = nominalFPS > 0 ? Double(nominalFPS) : 30.0

            let isSupported = await validateVideoTrack(track)
            guard isSupported else { return }

            let naturalSize = try await track.load(.naturalSize)
            let preferredTransform = try await track.load(.preferredTransform)
            let transformed = naturalSize.applying(preferredTransform)
            resolution = CGSize(width: abs(transformed.width), height: abs(transformed.height))

            let duration = try await asset.load(.duration)
            let durationSeconds = duration.seconds
            durationFrames = durationSeconds.isFinite ? Int(round(durationSeconds * fps)) : 0

            let item = AVPlayerItem(asset: asset)
            let outputSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            let output = AVPlayerItemVideoOutput(pixelBufferAttributes: outputSettings)
            item.add(output)
            videoOutput = output
            player.replaceCurrentItem(with: item)
            hasVideo = true

            if FeatureFlags.enableAssetReaderRenderer {
                assetReaderSource = AssetReaderFrameSource(asset: asset, track: track, fps: fps)
            }
            if FeatureFlags.enablePrecisionImageGenerator {
                if let urlAsset = asset as? AVURLAsset {
                    let descriptor = AssetDescriptor(url: urlAsset.url)
                    if AVFoundationDecoder.canOpen(descriptor) {
                        do {
                            let decoder = try AVFoundationDecoder(asset: descriptor)
                            decoder.setFPSHint(fps)
                            precisionDecoder = decoder
                        } catch {
                            handleError(error)
                        }
                    }
                }
            }

            timecodeStartFrames = 0

            attachTimeObserver()
            attachEndObserver(item: item)

            updateDerivedState(for: player.currentTime())
        } catch {
            handleError(error)
        }
    }

    public func copyPixelBuffer(hostTime: CFTimeInterval) -> CVPixelBuffer? {
        if FeatureFlags.enableAssetReaderRenderer {
            let buffer = assetReaderSource?.currentPixelBuffer()
            if let buffer {
                debugVideoFrames += 1
                debugLastFrameAt = hostTime
                debugFrameSize = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
                let frozen = assetReaderSource?.isFrozenFrameActive() == true
                debugFrameSource = frozen ? "imageGen" : "assetReader"
            }
            return buffer
        }
        guard let output = videoOutput else { return nil }
        let itemTime = output.itemTime(forHostTime: hostTime)
        if output.hasNewPixelBuffer(forItemTime: itemTime) {
            let buffer = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
            if let buffer {
                debugVideoFrames += 1
                debugLastFrameAt = hostTime
                debugFrameSize = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
                debugFrameSource = "videoOutput"
            }
            return buffer
        }
        return nil
    }

    public func captureStillImage() async throws -> CGImage {
        if let precisionDecoder {
            let request = FrameRequest(frameIndex: frameIndex, priority: 2, allowApproximate: false)
            let decoded = try precisionDecoder.decodeFrame(request)
            return try Self.cgImage(from: decoded)
        }
        if let buffer = assetReaderSource?.currentPixelBuffer() {
            return try Self.cgImage(from: buffer)
        }
        throw CaptureError.noFrame
    }

    private func generateFrozenFrame(atFrameIndex frameIndex: Int) {
        guard let precisionDecoder else { return }
        imageGenQueue.async { [weak self] in
            guard let self else { return }
            do {
                let request = FrameRequest(frameIndex: frameIndex, priority: 1, allowApproximate: false)
                let decoded = try precisionDecoder.decodeFrame(request)
                Task { @MainActor in
                    switch decoded {
                    case .cgImage(let cgImage):
                        let buffer = self.makePixelBuffer(from: cgImage)
                        self.assetReaderSource?.setFrozenFrame(buffer)
                        self.debugLastPrecisionSource = "imageGen"
                        if let buffer {
                            self.debugVideoFrames += 1
                            self.debugFrameSize = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
                        }
                    case .pixelBuffer(let buffer):
                        self.assetReaderSource?.setFrozenFrame(buffer)
                        self.debugLastPrecisionSource = "decodeBuffer"
                        self.debugVideoFrames += 1
                        self.debugFrameSize = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
                    }
                    self.debugLastPrecisionAt = CACurrentMediaTime()
                }
            } catch {
                Task { @MainActor in
                    self.debugLastPrecisionSource = "imageGen-fail"
                    self.debugLastPrecisionAt = CACurrentMediaTime()
                }
                self.log.error("Precision decode failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func cgImage(from decoded: DecodedFrame) throws -> CGImage {
        switch decoded {
        case .cgImage(let image):
            return image
        case .pixelBuffer(let buffer):
            return try cgImage(from: buffer)
        }
    }

    private static func cgImage(from buffer: CVPixelBuffer) throws -> CGImage {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let rect = CGRect(
            x: 0,
            y: 0,
            width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer)
        )
        let context = CIContext()
        guard let image = context.createCGImage(ciImage, from: rect) else {
            throw CaptureError.noFrame
        }
        return image
    }

    private func makePixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let width = image.width
        let height = image.height

        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else { return nil }

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
        ) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }

    public func recordRenderTick(hostTime: CFTimeInterval) {
        debugRenderTicks += 1
        debugLastRenderAt = hostTime
    }

    private func attachTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }

        let interval = CMTime(seconds: 1.0 / max(fps, 30.0), preferredTimescale: preferredTimeScale)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.updateDerivedState(for: time)
            }
        }
    }

    private func attachEndObserver(item: AVPlayerItem) {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
        }
    }

    private func updateDerivedState(for time: CMTime) {
        let previousFrame = frameIndex
        let seconds = time.seconds.isFinite ? time.seconds : 0
        currentTimeSeconds = seconds

        if fps > 0 {
            frameIndex = max(0, Int(round(seconds * fps)))
            let timecodeFrames = frameIndex + timecodeStartFrames
            timecode = TimecodeFormatter.timecodeString(frameIndex: timecodeFrames, fps: fps)
        } else {
            frameIndex = 0
            timecode = "00:00:00:00"
        }

        handleLoopIfNeeded(previousFrame: previousFrame)
    }

    private func handleError(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        lastErrorMessage = message
        log.error("Player error: \(message, privacy: .public)")
    }

    public func play() {
        stopReverseTimer()
        enterRealTimeMode()
        setState(.playing)
        player.rate = 1.0
        playbackRate = 1.0
        if FeatureFlags.enableAssetReaderRenderer {
            assetReaderSource?.clearFrozenFrame()
            assetReaderSource?.start()
        }
        if let clampedStart = clampedFrameIndex(frameIndex),
           fps > 0,
           clampedStart != frameIndex {
            seek(toFrameIndex: clampedStart, precision: false)
        }
        log.info("Play")
    }

    public func pause() {
        stopReverseTimer()
        player.rate = 0
        playbackRate = 0
        setState(.paused)
        if FeatureFlags.enableAssetReaderRenderer {
            assetReaderSource?.stop()
        }
        log.info("Pause")
    }

    public func stop() {
        pause()
        setState(.stopped)
        if let startFrame = clampedFrameIndex(0), fps > 0 {
            seek(toFrameIndex: startFrame, precision: false)
        }
        log.info("Stop")
    }

    public func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    public func enterPrecisionMode(trigger: PrecisionTrigger = .none) {
        mode = .precision
        precisionTrigger = trigger
    }

    public func enterRealTimeMode() {
        mode = .realTime
        precisionTrigger = .none
    }

    public func handleJ() {
        if FeatureFlags.enableManualReversePlayback {
            startManualReverse()
        } else {
            player.rate = -1.0
            playbackRate = -1.0
            isPlaying = true
            mode = .realTime
        }
        log.info("JKL: J")
    }

    public func handleK() {
        pause()
        log.info("JKL: K")
    }

    public func handleL() {
        let newRate: Float
        if playbackRate >= 1.0 {
            newRate = min(playbackRate * 2.0, 4.0)
        } else {
            newRate = 1.0
        }
        stopReverseTimer()
        mode = .realTime
        player.rate = newRate
        playbackRate = newRate
        isPlaying = true
        log.info("JKL: L rate=\(newRate, privacy: .public)")
    }

    public func stepForward() {
        stepByFrames(1)
    }

    public func stepBackward() {
        stepByFrames(-1)
    }

    public func seek(toFrameIndex targetFrame: Int) {
        seek(toFrameIndex: targetFrame, precision: true)
    }

    public func setInPoint() {
        inPointFrame = frameIndex
        if let outPoint = outPointFrame, outPoint < frameIndex {
            outPointFrame = frameIndex
        }
        log.info("Set In Point: \(self.frameIndex, privacy: .public)")
    }

    public func setOutPoint() {
        let candidate = frameIndex
        if let inPoint = inPointFrame {
            outPointFrame = max(candidate, inPoint)
        } else {
            outPointFrame = candidate
        }
        log.info("Set Out Point: \(self.outPointFrame ?? candidate, privacy: .public)")
    }

    public func clearInOut() {
        inPointFrame = nil
        outPointFrame = nil
        log.info("Clear In/Out")
    }

    public func toggleLooping() {
        isLooping.toggle()
        log.info("Looping: \(self.isLooping ? "ON" : "OFF", privacy: .public)")
    }

    public func prepareForAnnotation() {
        enterPrecisionMode(trigger: .annotate)
    }

    public func prepareForExportStill() {
        enterPrecisionMode(trigger: .exportStill)
    }

    private func seek(toFrameIndex targetFrame: Int, precision: Bool, clearLoopFlag: Bool = false) {
        guard fps > 0 else { return }
        let clamped = clampedFrameIndex(targetFrame) ?? targetFrame
        let seconds = Double(clamped) / fps
        seek(toSeconds: seconds, precision: precision, clearLoopFlag: clearLoopFlag)
    }

    private func stepByFrames(_ delta: Int) {
        guard fps > 0 else { return }
        pause()
        enterPrecisionMode(trigger: .step)

        let stepFrames = frameIndex + delta
        let clamped = clampedFrameIndex(stepFrames) ?? stepFrames
        seek(toFrameIndex: clamped, precision: true)
        log.info("Step \(delta, privacy: .public) -> \(clamped, privacy: .public)")
    }

    private func seek(toSeconds seconds: Double, precision: Bool, clearLoopFlag: Bool = false) {
        let time = CMTime(seconds: seconds, preferredTimescale: preferredTimeScale)
        let tolerance = precision ? CMTime.zero : CMTime(seconds: 0.05, preferredTimescale: preferredTimeScale)
        player.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.updateDerivedState(for: self.player.currentTime())
                if precision {
                    self.enterPrecisionMode(trigger: .seek)
                }
                if FeatureFlags.enablePrecisionImageGenerator && precision, self.precisionDecoder != nil {
                    self.assetReaderSource?.stop()
                    let targetFrame = Int(round(seconds * max(self.fps, 1.0)))
                    self.generateFrozenFrame(atFrameIndex: targetFrame)
                } else if FeatureFlags.enableAssetReaderRenderer {
                    self.assetReaderSource?.restart(atSeconds: seconds)
                }
                if clearLoopFlag {
                    self.loopSeekInFlight = false
                }
            }
        }
    }

    private func startManualReverse() {
        pause()
        enterPrecisionMode(trigger: .step)
        playbackRate = -1.0
        setState(.playing)

        stopReverseTimer()
        let interval = 1.0 / max(fps, 24.0)
        reverseTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.stepByFrames(-1)
            }
        }
    }

    private func stopReverseTimer() {
        reverseTimer?.invalidate()
        reverseTimer = nil
    }

    private func setState(_ newState: PlaybackState) {
        state = newState
        isPlaying = newState == .playing
    }

    private func clampedFrameIndex(_ frame: Int) -> Int? {
        var result = frame
        if let inPoint = inPointFrame {
            result = max(result, inPoint)
        }
        if let outPoint = outPointFrame {
            result = min(result, outPoint)
        }
        return result
    }

    private func handleLoopIfNeeded(previousFrame: Int) {
        guard state == .playing else { return }
        guard let outPoint = outPointFrame else { return }
        guard fps > 0 else { return }
        if loopSeekInFlight { return }

        let crossedOutPoint = previousFrame < outPoint && frameIndex >= outPoint
        let atOrPastOutPoint = frameIndex >= outPoint

        if crossedOutPoint || atOrPastOutPoint {
            if isLooping {
                let targetFrame = inPointFrame ?? 0
                loopSeekInFlight = true
                seek(toFrameIndex: targetFrame, precision: false, clearLoopFlag: true)
                log.info("Loop -> \(targetFrame, privacy: .public)")
            } else {
                pause()
            }
        }
    }

    private func validateVideoTrack(_ track: AVAssetTrack) async -> Bool {
        do {
            let descriptions = try await track.load(.formatDescriptions)
            guard let format = descriptions.first else { return true }
            let subtype = CMFormatDescriptionGetMediaSubType(format)
            if supportedCodecSubtypes.contains(subtype) {
                return true
            }
            handleError(PlayerCoreError.failedToLoad("Unsupported codec: \(fourCCString(subtype))"))
            return false
        } catch {
            handleError(error)
            return false
        }
    }

    private func fourCCString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .macOSRoman) ?? String(format: "0x%08X", code)
    }

    private var supportedCodecSubtypes: Set<FourCharCode> {
        [
            kCMVideoCodecType_H264,
            kCMVideoCodecType_HEVC,
            kCMVideoCodecType_HEVCWithAlpha,
            kCMVideoCodecType_AppleProRes422,
            kCMVideoCodecType_AppleProRes422HQ,
            kCMVideoCodecType_AppleProRes422LT,
            kCMVideoCodecType_AppleProRes422Proxy,
            kCMVideoCodecType_AppleProRes4444,
            kCMVideoCodecType_AppleProRes4444XQ
        ]
    }

}

public enum FeatureFlags {
    public static let enableManualReversePlayback = true
    public static let enableAssetReaderRenderer = true
    public static let enablePrecisionImageGenerator = true
}

public enum TimecodeFormatter {
    public static func timecodeString(frameIndex: Int, fps: Double) -> String {
        guard fps > 0 else { return "00:00:00:00" }
        let fpsInt = max(1, Int(round(fps)))
        let totalFrames = max(0, frameIndex)
        let frames = totalFrames % fpsInt
        let totalSeconds = totalFrames / fpsInt
        let seconds = totalSeconds % 60
        let totalMinutes = totalSeconds / 60
        let minutes = totalMinutes % 60
        let hours = totalMinutes / 60
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }

    public static func frames(from timecode: String, fps: Double) -> Int? {
        let parts = timecode.split(separator: ":")
        guard parts.count == 4 else { return nil }
        guard let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              let seconds = Int(parts[2]),
              let frames = Int(parts[3]) else { return nil }
        let fpsInt = max(1, Int(round(fps)))
        return (((hours * 60 + minutes) * 60 + seconds) * fpsInt) + frames
    }
}
