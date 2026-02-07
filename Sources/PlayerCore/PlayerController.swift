@preconcurrency import AVFoundation
import Combine
import Foundation
import os
import DecodeKit

public enum PlaybackMode: String {
    case realTime = "REAL-TIME"
    case precision = "PRECISION"
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

@MainActor
public final class PlayerController: ObservableObject {
    public let player: AVPlayer

    @Published public private(set) var mode: PlaybackMode = .realTime
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

    private let log = Logger(subsystem: "PolePlayer", category: "PlayerCore")
    private var timeObserverToken: Any?
    private var endObserver: NSObjectProtocol?
    private var reverseTimer: Timer?
    private var asset: AVAsset?
    private var videoOutput: AVPlayerItemVideoOutput?
    private var assetReaderSource: AssetReaderFrameSource?

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
        lastErrorMessage = nil
        debugVideoFrames = 0
        debugLastFrameAt = 0
        debugFrameSize = .zero
        debugFrameSource = "none"
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
                debugFrameSource = "assetReader"
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
        let seconds = time.seconds.isFinite ? time.seconds : 0
        currentTimeSeconds = seconds

        if fps > 0 {
            frameIndex = max(0, Int(round(seconds * fps)))
            timecode = TimecodeFormatter.timecodeString(frameIndex: frameIndex, fps: fps)
        } else {
            frameIndex = 0
            timecode = "00:00:00:00"
        }
    }

    private func handleError(_ error: Error) {
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        lastErrorMessage = message
        log.error("Player error: \(message, privacy: .public)")
    }

    public func play() {
        stopReverseTimer()
        mode = .realTime
        player.rate = 1.0
        playbackRate = 1.0
        isPlaying = true
        if FeatureFlags.enableAssetReaderRenderer {
            assetReaderSource?.start()
        }
        log.info("Play")
    }

    public func pause() {
        stopReverseTimer()
        player.rate = 0
        playbackRate = 0
        isPlaying = false
        if FeatureFlags.enableAssetReaderRenderer {
            assetReaderSource?.stop()
        }
        log.info("Pause")
    }

    public func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    public func enterPrecisionMode() {
        mode = .precision
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
        guard fps > 0 else { return }
        let seconds = Double(targetFrame) / fps
        seek(toSeconds: seconds, precision: true)
    }

    private func stepByFrames(_ delta: Int) {
        guard fps > 0 else { return }
        pause()
        mode = .precision

        let stepSeconds = Double(delta) / fps
        let targetSeconds = max(0, currentTimeSeconds + stepSeconds)
        seek(toSeconds: targetSeconds, precision: true)
        log.info("Step \(delta, privacy: .public) -> \(targetSeconds, privacy: .public)")
    }

    private func seek(toSeconds seconds: Double, precision: Bool) {
        let time = CMTime(seconds: seconds, preferredTimescale: preferredTimeScale)
        let tolerance = precision ? CMTime.zero : CMTime(seconds: 0.05, preferredTimescale: preferredTimeScale)
        player.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.updateDerivedState(for: self.player.currentTime())
                if FeatureFlags.enableAssetReaderRenderer {
                    self.assetReaderSource?.restart(atSeconds: seconds)
                }
            }
        }
    }

    private func startManualReverse() {
        pause()
        mode = .precision
        playbackRate = -1.0
        isPlaying = true

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
}

public enum FeatureFlags {
    public static let enableManualReversePlayback = true
    public static let enableAssetReaderRenderer = true
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
}
