import CoreVideo
import Foundation

public struct PixelColor: Equatable, Sendable {
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8

    public var rNorm: Float { Float(r) / 255 }
    public var gNorm: Float { Float(g) / 255 }
    public var bNorm: Float { Float(b) / 255 }

    public var hex: String { String(format: "#%02X%02X%02X", r, g, b) }
}

public enum PixelSampler {
    public static func sample(from pixelBuffer: CVPixelBuffer, x: Int, y: Int) -> PixelColor? {
        let fmt = CVPixelBufferGetPixelFormatType(pixelBuffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let ptr = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let w   = CVPixelBufferGetWidth(pixelBuffer)
        let h   = CVPixelBufferGetHeight(pixelBuffer)
        let bpr = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard x >= 0, x < w, y >= 0, y < h else { return nil }

        let px = ptr.assumingMemoryBound(to: UInt8.self)
        let o  = y * bpr + x * 4

        switch fmt {
        case kCVPixelFormatType_32BGRA:
            return PixelColor(r: px[o + 2], g: px[o + 1], b: px[o + 0])
        case kCVPixelFormatType_32ARGB:
            return PixelColor(r: px[o + 1], g: px[o + 2], b: px[o + 3])
        case kCVPixelFormatType_32RGBA:
            return PixelColor(r: px[o + 0], g: px[o + 1], b: px[o + 2])
        default:
            return nil
        }
    }
}
