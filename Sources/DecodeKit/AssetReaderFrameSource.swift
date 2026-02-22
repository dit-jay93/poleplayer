import AVFoundation
import CoreVideo
import Foundation

public final class AssetReaderFrameSource {
    private let asset: AVAsset
    private let track: AVAssetTrack
    private let fps: Double
    private let outputSettings: [String: Any]
    private let queue = DispatchQueue(label: "DecodeKit.AssetReaderFrameSource")
    private let lock = NSLock()

    private var reader: AVAssetReader?
    private var output: AVAssetReaderTrackOutput?
    private var timer: DispatchSourceTimer?
    private var currentBuffer: CVPixelBuffer?
    private var frozenBuffer: CVPixelBuffer?

    public init(asset: AVAsset, track: AVAssetTrack, fps: Double) {
        self.asset = asset
        self.track = track
        self.fps = fps > 0 ? fps : 30.0
        self.outputSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
    }

    deinit {
        stop()
    }

    public func start() {
        start(atSeconds: 0)
    }

    public func restart(atSeconds seconds: Double) {
        stop()
        start(atSeconds: seconds)
    }

    public func stop() {
        queue.sync { stopOnQueue() }
        lock.lock()
        currentBuffer = nil
        frozenBuffer = nil
        lock.unlock()
    }

    /// queue 위에서 이미 실행 중일 때 타이머/리더를 정리합니다 (queue.sync 없이).
    private func stopOnQueue() {
        timer?.cancel()
        timer = nil
        reader?.cancelReading()
        reader = nil
        output = nil
    }

    public func currentPixelBuffer() -> CVPixelBuffer? {
        lock.lock()
        let buffer = frozenBuffer ?? currentBuffer
        lock.unlock()
        return buffer
    }

    public func isFrozenFrameActive() -> Bool {
        lock.lock()
        let active = frozenBuffer != nil
        lock.unlock()
        return active
    }

    public func setFrozenFrame(_ buffer: CVPixelBuffer?) {
        lock.lock()
        frozenBuffer = buffer
        lock.unlock()
    }

    public func clearFrozenFrame() {
        lock.lock()
        frozenBuffer = nil
        lock.unlock()
    }

    private func start(atSeconds seconds: Double) {
        queue.async {
            do {
                let reader = try AVAssetReader(asset: self.asset)
                let output = AVAssetReaderTrackOutput(track: self.track, outputSettings: self.outputSettings)
                output.alwaysCopiesSampleData = true

                if seconds > 0 {
                    let start = CMTime(seconds: seconds, preferredTimescale: 600)
                    reader.timeRange = CMTimeRange(start: start, duration: .positiveInfinity)
                }

                guard reader.canAdd(output) else { return }
                reader.add(output)

                self.reader = reader
                self.output = output

                guard reader.startReading() else { return }

                self.startTimer()
            } catch {
                return
            }
        }
    }

    private func startTimer() {
        let interval = 1.0 / max(fps, 1.0)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.readNextFrame()
        }
        self.timer = timer
        timer.resume()
    }

    private func readNextFrame() {
        guard let reader, let output else { return }
        if reader.status != .reading {
            stopOnQueue()   // 이미 queue 위 — queue.sync 없이 직접 정리
            return
        }

        guard let sampleBuffer = output.copyNextSampleBuffer(),
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            stopOnQueue()   // 이미 queue 위 — queue.sync 없이 직접 정리
            return
        }

        lock.lock()
        currentBuffer = imageBuffer
        lock.unlock()
    }
}
