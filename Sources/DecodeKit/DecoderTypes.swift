import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

public struct DecodeCapability: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let randomAccess = DecodeCapability(rawValue: 1 << 0)
    public static let timecode = DecodeCapability(rawValue: 1 << 1)
    public static let gpuOutput = DecodeCapability(rawValue: 1 << 2)
}

public struct AssetDescriptor {
    public let url: URL
    public let typeHint: String?

    public init(url: URL, typeHint: String? = nil) {
        self.url = url
        self.typeHint = typeHint
    }
}

public struct FrameRequest {
    public let frameIndex: Int
    public let priority: Int
    public let allowApproximate: Bool

    public init(frameIndex: Int, priority: Int = 0, allowApproximate: Bool = false) {
        self.frameIndex = frameIndex
        self.priority = priority
        self.allowApproximate = allowApproximate
    }
}

public enum DecodedFrame {
    case cgImage(CGImage)
    case pixelBuffer(CVPixelBuffer)
}

public protocol DecoderPlugin {
    static var pluginID: String { get }
    static var displayName: String { get }
    static var supportedExtensions: [String] { get }

    static func canOpen(_ asset: AssetDescriptor) -> Bool

    init(asset: AssetDescriptor) throws
    func prepare()
    func decodeFrame(_ request: FrameRequest) throws -> DecodedFrame
    func prefetch(frames: [Int])
    func close()
}

public final class AVFoundationDecoder: DecoderPlugin, @unchecked Sendable {
    public static let pluginID = "decode.avfoundation"
    public static let displayName = "AVFoundation"
    public static let supportedExtensions = ["mov", "mp4", "m4v"]

    private let asset: AVURLAsset
    private let imageGenerator: AVAssetImageGenerator
    private var fps: Double = 30.0

    public static func canOpen(_ asset: AssetDescriptor) -> Bool {
        let ext = asset.url.pathExtension.lowercased()
        return supportedExtensions.contains(ext)
    }

    public init(asset: AssetDescriptor) throws {
        guard Self.canOpen(asset) else {
            throw NSError(domain: "DecodeKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported asset"]) 
        }
        self.asset = AVURLAsset(url: asset.url)
        self.imageGenerator = AVAssetImageGenerator(asset: self.asset)
        self.imageGenerator.appliesPreferredTrackTransform = true
        self.imageGenerator.requestedTimeToleranceBefore = .zero
        self.imageGenerator.requestedTimeToleranceAfter = .zero
        Task { [weak self] in
            guard let self else { return }
            do {
                let tracks = try await self.asset.loadTracks(withMediaType: .video)
                if let track = tracks.first {
                    let nominal = try await track.load(.nominalFrameRate)
                    let value = Double(nominal)
                    self.fps = value > 0 ? value : 30.0
                }
            } catch {
                // Keep default fps when loading fails.
            }
        }
    }

    public func prepare() {
        // AVFoundation prepares lazily; no-op for now.
    }

    public func decodeFrame(_ request: FrameRequest) throws -> DecodedFrame {
        let seconds = Double(request.frameIndex) / max(fps, 1.0)
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        var actualTime = CMTime.zero
        let image = try imageGenerator.copyCGImage(at: time, actualTime: &actualTime)
        return .cgImage(image)
    }

    public func prefetch(frames: [Int]) {
        // Placeholder for future cache warming.
        _ = frames
    }

    public func close() {
        // No resources to release yet.
    }
}
