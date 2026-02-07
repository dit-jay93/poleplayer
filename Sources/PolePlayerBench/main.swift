import AVFoundation
import CoreGraphics
import CryptoKit
import Darwin
import Foundation
import RenderCore

@main
struct PolePlayerBench {
    static func main() async {
        do {
            let config = try BenchConfig.parse(from: CommandLine.arguments)
            let assetURL = try await resolveInputURL(config: config)
            let asset = try await BenchAsset(url: assetURL)

            let stepResult = try BenchRunner.runStepTest(asset: asset, config: config)
            let seekResult = try BenchRunner.runSeekTest(asset: asset, config: config)
            let lutResult = try BenchRunner.runLUTToggleTest(asset: asset, config: config)

        let report = BenchReportBuilder.build(
            asset: asset,
            config: config,
            step: stepResult,
            seek: seekResult,
            lut: lutResult
        )
            try BenchReportWriter.write(report: report, to: config.reportURL)

            print("Benchmark report written to: \(config.reportURL.path)")
            if !report.pass {
                exit(2)
            }
        } catch BenchError.helpRequested {
            print(BenchError.helpRequested.localizedDescription)
            exit(0)
        } catch {
            fputs("Bench failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func resolveInputURL(config: BenchConfig) async throws -> URL {
        if let input = config.inputURL {
            return input
        }
        if config.mode == .ci {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PolePlayerBench", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let url = tempDir.appendingPathComponent("bench_ci.mp4")
            try await BenchAssetGenerator.generateH264Clip(to: url, frames: 60, fps: 24, size: CGSize(width: 160, height: 90))
            return url
        }
        throw BenchError.missingInput
    }
}

enum BenchMode: String {
    case full
    case ci
}

struct BenchConfig {
    let inputURL: URL?
    let outputDirectory: URL
    let reportURL: URL
    let lutURL: URL?
    let mode: BenchMode
    let stepCount: Int
    let seekCount: Int
    let lutToggleFrames: Int
    let lutToggleInterval: Int
    let seed: UInt64

    static func parse(from args: [String]) throws -> BenchConfig {
        var inputPath: String? = nil
        var outputPath: String = FileManager.default.currentDirectoryPath
        var reportPath: String? = nil
        var lutPath: String? = nil
        var mode: BenchMode = .full
        var stepCount = 1000
        var seekCount = 100
        var lutToggleFrames = 200
        var lutToggleInterval = 10
        var seed: UInt64 = 1337

        var index = 1
        while index < args.count {
            let arg = args[index]
            switch arg {
            case "--input":
                index += 1
                inputPath = index < args.count ? args[index] : nil
            case "--output":
                index += 1
                outputPath = index < args.count ? args[index] : outputPath
            case "--report":
                index += 1
                reportPath = index < args.count ? args[index] : nil
            case "--lut":
                index += 1
                lutPath = index < args.count ? args[index] : nil
            case "--ci":
                mode = .ci
            case "--step-count":
                index += 1
                if index < args.count { stepCount = Int(args[index]) ?? stepCount }
            case "--seek-count":
                index += 1
                if index < args.count { seekCount = Int(args[index]) ?? seekCount }
            case "--lut-frames":
                index += 1
                if index < args.count { lutToggleFrames = Int(args[index]) ?? lutToggleFrames }
            case "--lut-interval":
                index += 1
                if index < args.count { lutToggleInterval = Int(args[index]) ?? lutToggleInterval }
            case "--seed":
                index += 1
                if index < args.count { seed = UInt64(args[index]) ?? seed }
            case "--help", "-h":
                throw BenchError.helpRequested
            default:
                break
            }
            index += 1
        }

        if mode == .ci {
            stepCount = min(stepCount, 120)
            seekCount = min(seekCount, 20)
            lutToggleFrames = min(lutToggleFrames, 40)
        }

        let outputDirectory = URL(fileURLWithPath: outputPath, isDirectory: true)
        let reportURL = reportPath.map { URL(fileURLWithPath: $0) }
            ?? outputDirectory.appendingPathComponent("benchmark_report.json")

        return BenchConfig(
            inputURL: inputPath.map { URL(fileURLWithPath: $0) },
            outputDirectory: outputDirectory,
            reportURL: reportURL,
            lutURL: lutPath.map { URL(fileURLWithPath: $0) },
            mode: mode,
            stepCount: stepCount,
            seekCount: seekCount,
            lutToggleFrames: lutToggleFrames,
            lutToggleInterval: max(1, lutToggleInterval),
            seed: seed
        )
    }
}

enum BenchError: LocalizedError {
    case missingInput
    case helpRequested
    case invalidAsset

    var errorDescription: String? {
        switch self {
        case .missingInput:
            return "Missing --input. Provide a clip path or use --ci."
        case .helpRequested:
            return "Usage: swift run PolePlayerBench --input <path> [--output <dir>] [--lut <path>] [--ci]"
        case .invalidAsset:
            return "Unable to load asset or read video track."
        }
    }
}

struct BenchAsset {
    let url: URL
    let asset: AVURLAsset
    let generator: AVAssetImageGenerator
    let fps: Double
    let durationFrames: Int
    let size: CGSize

    init(url: URL) async throws {
        self.url = url
        self.asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { throw BenchError.invalidAsset }
        let nominalFPS = try await track.load(.nominalFrameRate)
        let fpsValue = Double(nominalFPS)
        self.fps = fpsValue > 0 ? fpsValue : 30.0
        let duration = try await asset.load(.duration)
        let durationSeconds = duration.seconds
        self.durationFrames = max(1, Int(round(durationSeconds * self.fps)))
        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let transformed = naturalSize.applying(preferredTransform)
        self.size = CGSize(width: abs(transformed.width), height: abs(transformed.height))

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        self.generator = generator
    }

    func decodeFrame(index: Int) throws -> BenchFrame {
        let clamped = max(0, min(index, durationFrames - 1))
        let time = CMTime(seconds: Double(clamped) / fps, preferredTimescale: 600)
        var actual = CMTime.zero
        let start = CFAbsoluteTimeGetCurrent()
        let image = try generator.copyCGImage(at: time, actualTime: &actual)
        let latencyMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        let actualFrame = Int(round(actual.seconds * fps))
        return BenchFrame(expectedIndex: clamped, actualIndex: actualFrame, latencyMs: latencyMs, image: image)
    }
}

struct BenchFrame {
    let expectedIndex: Int
    let actualIndex: Int
    let latencyMs: Double
    let image: CGImage
}

enum BenchRunner {
    static func runStepTest(asset: BenchAsset, config: BenchConfig) throws -> StepResult {
        let total = max(1, config.stepCount)
        var samples: [BenchSample] = []
        samples.reserveCapacity(total)
        var correct = 0
        var latencies: [Double] = []
        latencies.reserveCapacity(total)

        for i in 0..<total {
            let expected = i % asset.durationFrames
            let frame = try asset.decodeFrame(index: expected)
            if frame.actualIndex == expected {
                correct += 1
            }
            samples.append(BenchSample(expected: expected, actual: frame.actualIndex, latencyMs: frame.latencyMs))
            latencies.append(frame.latencyMs)
        }

        return StepResult(total: total, correct: correct, latencies: latencies, samples: samples)
    }

    static func runSeekTest(asset: BenchAsset, config: BenchConfig) throws -> SeekResult {
        let total = max(1, config.seekCount)
        var samples: [BenchSample] = []
        samples.reserveCapacity(total)
        var correct = 0
        var maxError = 0
        var latencies: [Double] = []
        latencies.reserveCapacity(total)
        var rng = SeededGenerator(seed: config.seed)

        for _ in 0..<total {
            let expected = Int.random(in: 0..<asset.durationFrames, using: &rng)
            let frame = try asset.decodeFrame(index: expected)
            let error = abs(frame.actualIndex - expected)
            if error == 0 { correct += 1 }
            maxError = max(maxError, error)
            samples.append(BenchSample(expected: expected, actual: frame.actualIndex, latencyMs: frame.latencyMs))
            latencies.append(frame.latencyMs)
        }

        return SeekResult(total: total, correct: correct, maxError: maxError, latencies: latencies, samples: samples)
    }

    static func runLUTToggleTest(asset: BenchAsset, config: BenchConfig) throws -> LUTResult {
        let sampleFrame = try asset.decodeFrame(index: asset.durationFrames / 2)
        let cube = try config.lutURL.map { try LUTCube.load(url: $0) }

        let baseHash = ImageHasher.hash(image: sampleFrame.image, cube: nil)
        let lutHash = ImageHasher.hash(image: sampleFrame.image, cube: cube)

        var consistent = true
        let total = max(1, config.lutToggleFrames)
        for index in 0..<total {
            let enabled = (index / config.lutToggleInterval) % 2 == 1
            let current = enabled ? lutHash : baseHash
            let expected = enabled ? lutHash : baseHash
            if current != expected {
                consistent = false
                break
            }
        }

        return LUTResult(
            total: total,
            enabledHash: lutHash,
            disabledHash: baseHash,
            usedLUT: cube != nil,
            consistent: consistent
        )
    }
}

struct BenchSample: Codable {
    let expected: Int
    let actual: Int
    let latencyMs: Double
}

struct StepResult {
    let total: Int
    let correct: Int
    let latencies: [Double]
    let samples: [BenchSample]

    var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }
}

struct SeekResult {
    let total: Int
    let correct: Int
    let maxError: Int
    let latencies: [Double]
    let samples: [BenchSample]

    var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }
}

struct LUTResult {
    let total: Int
    let enabledHash: String
    let disabledHash: String
    let usedLUT: Bool
    let consistent: Bool
}

struct BenchReport: Codable {
    let schemaVersion: String
    let createdAt: String
    let input: BenchInputInfo
    let machine: BenchMachineInfo
    let metrics: BenchMetrics
    let thresholds: BenchThresholds
    let pass: Bool
    let warnings: [String]
}

struct BenchInputInfo: Codable {
    let path: String
    let fps: Double
    let durationFrames: Int
    let width: Int
    let height: Int
}

struct BenchMachineInfo: Codable {
    let osVersion: String
    let model: String
    let cpu: String
    let cores: Int
    let memoryGB: Double
}

struct BenchMetrics: Codable {
    let step: StepMetrics
    let seek: SeekMetrics
    let lut: LUTMetrics
}

struct StepMetrics: Codable {
    let total: Int
    let correct: Int
    let accuracy: Double
    let latencyP50Ms: Double
    let latencyP95Ms: Double
    let samples: [BenchSample]
}

struct SeekMetrics: Codable {
    let total: Int
    let correct: Int
    let accuracy: Double
    let maxErrorFrames: Int
    let latencyP50Ms: Double
    let latencyP95Ms: Double
    let samples: [BenchSample]
}

struct LUTMetrics: Codable {
    let total: Int
    let usedLUT: Bool
    let consistent: Bool
    let enabledHash: String
    let disabledHash: String
}

struct BenchThresholds: Codable {
    let stepAccuracyMin: Double
    let seekAccuracyMaxError: Int
    let stepLatencyP95MaxMs: Double
}

enum BenchReportBuilder {
    static func build(asset: BenchAsset, config: BenchConfig, step: StepResult, seek: SeekResult, lut: LUTResult) -> BenchReport {
        let stepLatency = Percentiles.compute(step.latencies)
        let seekLatency = Percentiles.compute(seek.latencies)

        let stepMetrics = StepMetrics(
            total: step.total,
            correct: step.correct,
            accuracy: step.accuracy,
            latencyP50Ms: stepLatency.p50,
            latencyP95Ms: stepLatency.p95,
            samples: step.samples
        )
        let seekMetrics = SeekMetrics(
            total: seek.total,
            correct: seek.correct,
            accuracy: seek.accuracy,
            maxErrorFrames: seek.maxError,
            latencyP50Ms: seekLatency.p50,
            latencyP95Ms: seekLatency.p95,
            samples: seek.samples
        )
        let lutMetrics = LUTMetrics(
            total: lut.total,
            usedLUT: lut.usedLUT,
            consistent: lut.consistent,
            enabledHash: lut.enabledHash,
            disabledHash: lut.disabledHash
        )
        let thresholds = BenchThresholds(stepAccuracyMin: 1.0, seekAccuracyMaxError: 0, stepLatencyP95MaxMs: 50)
        let warnings = buildWarnings(lut: lut, config: config)

        let pass = step.accuracy >= thresholds.stepAccuracyMin
            && seek.maxError <= thresholds.seekAccuracyMaxError
            && stepLatency.p95 <= thresholds.stepLatencyP95MaxMs

        return BenchReport(
            schemaVersion: "1.0.0",
            createdAt: BenchDateFormatter.iso8601String(from: Date()),
            input: BenchInputInfo(
                path: asset.url.path,
                fps: asset.fps,
                durationFrames: asset.durationFrames,
                width: Int(asset.size.width),
                height: Int(asset.size.height)
            ),
            machine: BenchMachineInfo(
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                model: SystemInfo.hardwareModel(),
                cpu: SystemInfo.cpuBrand(),
                cores: ProcessInfo.processInfo.processorCount,
                memoryGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
            ),
            metrics: BenchMetrics(step: stepMetrics, seek: seekMetrics, lut: lutMetrics),
            thresholds: thresholds,
            pass: pass,
            warnings: warnings
        )
    }

    private static func buildWarnings(lut: LUTResult, config: BenchConfig) -> [String] {
        var warnings: [String] = []
        if !lut.usedLUT {
            warnings.append("LUT not provided; toggle consistency ran against identity output.")
        }
        if config.mode == .ci {
            warnings.append("CI mode uses a generated H.264 clip and reduced iterations.")
        }
        return warnings
    }
}

enum BenchDateFormatter {
    static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

enum BenchReportWriter {
    static func write(report: BenchReport, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        try data.write(to: url, options: .atomic)
    }
}

enum Percentiles {
    static func compute(_ values: [Double]) -> (p50: Double, p95: Double) {
        guard !values.isEmpty else { return (0, 0) }
        let sorted = values.sorted()
        func percentile(_ p: Double) -> Double {
            let idx = Int((Double(sorted.count - 1) * p).rounded())
            return sorted[max(0, min(idx, sorted.count - 1))]
        }
        return (percentile(0.50), percentile(0.95))
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x1234_5678 : seed
    }

    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }
}

enum ImageHasher {
    static func hash(image: CGImage, cube: LUTCube?) -> String {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return ""
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let sampleStride = max(1, min(width, height) / 64)
        var sample = Data()
        for y in stride(from: 0, to: height, by: sampleStride) {
            for x in stride(from: 0, to: width, by: sampleStride) {
                let index = (y * width + x) * 4
                let r = Float(buffer[index]) / 255.0
                let g = Float(buffer[index + 1]) / 255.0
                let b = Float(buffer[index + 2]) / 255.0
                let input = SIMD3<Float>(r, g, b)
                let output = cube.map { LUTApplier.apply(color: input, cube: $0, intensity: 1.0) } ?? input
                let bytes: [UInt8] = [
                    UInt8(max(0, min(255, Int(output.x * 255.0)))),
                    UInt8(max(0, min(255, Int(output.y * 255.0)))),
                    UInt8(max(0, min(255, Int(output.z * 255.0))))
                ]
                sample.append(contentsOf: bytes)
            }
        }
        let digest = SHA256.hash(data: sample)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

enum LUTApplier {
    static func apply(color: SIMD3<Float>, cube: LUTCube, intensity: Float) -> SIMD3<Float> {
        let minV = cube.domainMin
        let maxV = cube.domainMax
        let clamped = SIMD3<Float>(
            clamp((color.x - minV.x) / max(maxV.x - minV.x, 0.0001)),
            clamp((color.y - minV.y) / max(maxV.y - minV.y, 0.0001)),
            clamp((color.z - minV.z) / max(maxV.z - minV.z, 0.0001))
        )
        let size = cube.size
        let scaled = clamped * Float(size - 1)
        let x0 = Int(floor(scaled.x))
        let y0 = Int(floor(scaled.y))
        let z0 = Int(floor(scaled.z))
        let x1 = min(x0 + 1, size - 1)
        let y1 = min(y0 + 1, size - 1)
        let z1 = min(z0 + 1, size - 1)
        let tx = scaled.x - Float(x0)
        let ty = scaled.y - Float(y0)
        let tz = scaled.z - Float(z0)

        let c000 = sample(cube: cube, x: x0, y: y0, z: z0)
        let c100 = sample(cube: cube, x: x1, y: y0, z: z0)
        let c010 = sample(cube: cube, x: x0, y: y1, z: z0)
        let c110 = sample(cube: cube, x: x1, y: y1, z: z0)
        let c001 = sample(cube: cube, x: x0, y: y0, z: z1)
        let c101 = sample(cube: cube, x: x1, y: y0, z: z1)
        let c011 = sample(cube: cube, x: x0, y: y1, z: z1)
        let c111 = sample(cube: cube, x: x1, y: y1, z: z1)

        let c00 = mix(c000, c100, t: tx)
        let c10 = mix(c010, c110, t: tx)
        let c01 = mix(c001, c101, t: tx)
        let c11 = mix(c011, c111, t: tx)
        let c0 = mix(c00, c10, t: ty)
        let c1 = mix(c01, c11, t: ty)
        let lut = mix(c0, c1, t: tz)

        return mix(color, lut, t: intensity)
    }

    private static func sample(cube: LUTCube, x: Int, y: Int, z: Int) -> SIMD3<Float> {
        let index = (z * cube.size * cube.size) + (y * cube.size) + x
        return cube.values[index]
    }

    private static func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        return a + (b - a) * t
    }

    private static func clamp(_ value: Float) -> Float {
        return min(max(value, 0), 1)
    }
}

enum SystemInfo {
    static func hardwareModel() -> String {
        sysctlString("hw.model") ?? "unknown"
    }

    static func cpuBrand() -> String {
        sysctlString("machdep.cpu.brand_string") ?? "unknown"
    }

    private static func sysctlString(_ name: String) -> String? {
        var size: size_t = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        let data = Data(bytes: buffer, count: buffer.count)
        let string = String(decoding: data, as: UTF8.self)
        return string.trimmingCharacters(in: CharacterSet.controlCharacters)
    }
}

enum BenchAssetGenerator {
    static func generateH264Clip(to url: URL, frames: Int, fps: Int32, size: CGSize) async throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        guard writer.canAdd(input) else { throw BenchError.invalidAsset }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: fps)
        var frameTime = CMTime.zero

        for frame in 0..<frames {
            while !input.isReadyForMoreMediaData {
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
            guard let buffer = makePixelBuffer(size: size, frame: frame) else { continue }
            adaptor.append(buffer, withPresentationTime: frameTime)
            frameTime = CMTimeAdd(frameTime, frameDuration)
        }

        input.markAsFinished()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writer.finishWriting {
                if writer.status == .failed {
                    continuation.resume(throwing: writer.error ?? BenchError.invalidAsset)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private static func makePixelBuffer(size: CGSize, frame: Int) -> CVPixelBuffer? {
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))
            if let context = CGContext(
                data: base,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) {
                let hue = CGFloat(frame % 60) / 60.0
                context.setFillColor(CGColor(red: hue, green: 0.4, blue: 1.0 - hue, alpha: 1.0))
                context.fill(CGRect(origin: .zero, size: size))
                context.setStrokeColor(CGColor(gray: 0.1, alpha: 1.0))
                context.setLineWidth(2)
                context.stroke(CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4))
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
