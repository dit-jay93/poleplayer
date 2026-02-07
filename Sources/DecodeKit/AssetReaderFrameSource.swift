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
        queue.sync {
            timer?.cancel()
            timer = nil
            reader?.cancelReading()
            reader = nil
            output = nil
        }
        lock.lock()
        currentBuffer = nil
        lock.unlock()
    }

    public func currentPixelBuffer() -> CVPixelBuffer? {
        lock.lock()
        let buffer = currentBuffer
        lock.unlock()
        return buffer
    }

    private func start(atSeconds seconds: Double) {
        queue.async {
            do {
                let reader = try AVAssetReader(asset: self.asset)
                let output = AVAssetReaderTrackOutput(track: self.track, outputSettings: self.outputSettings)
                output.alwaysCopiesSampleData = false

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
            stop()
            return
        }

        guard let sampleBuffer = output.copyNextSampleBuffer(),
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            stop()
            return
        }

        lock.lock()
        currentBuffer = imageBuffer
        lock.unlock()
    }
}
