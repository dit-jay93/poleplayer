import CoreVideo
import Foundation

public struct HistogramData: Equatable, Sendable {
    public let red: [Float]    // 256 bins, normalized 0..1 relative to peak
    public let green: [Float]
    public let blue: [Float]
    public let luma: [Float]
}

public enum HistogramComputer {
    private static let bins = 256
    private static let step = 4  // sample every 4th pixel in each axis

    public static func compute(from pixelBuffer: CVPixelBuffer) -> HistogramData? {
        let fmt = CVPixelBufferGetPixelFormatType(pixelBuffer)
        switch fmt {
        case kCVPixelFormatType_32BGRA:
            return fromPacked(pixelBuffer, rOff: 2, gOff: 1, bOff: 0)
        case kCVPixelFormatType_32ARGB:
            return fromPacked(pixelBuffer, rOff: 1, gOff: 2, bOff: 3)
        case kCVPixelFormatType_32RGBA:
            return fromPacked(pixelBuffer, rOff: 0, gOff: 1, bOff: 2)
        default:
            return nil
        }
    }

    private static func fromPacked(
        _ buf: CVPixelBuffer,
        rOff: Int, gOff: Int, bOff: Int
    ) -> HistogramData? {
        CVPixelBufferLockBaseAddress(buf, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buf, .readOnly) }
        guard let ptr = CVPixelBufferGetBaseAddress(buf) else { return nil }

        let w   = CVPixelBufferGetWidth(buf)
        let h   = CVPixelBufferGetHeight(buf)
        let bpr = CVPixelBufferGetBytesPerRow(buf)
        let px  = ptr.assumingMemoryBound(to: UInt8.self)

        var r = [Int](repeating: 0, count: bins)
        var g = [Int](repeating: 0, count: bins)
        var b = [Int](repeating: 0, count: bins)
        var y = [Int](repeating: 0, count: bins)
        var total = 0

        var row = 0
        while row < h {
            var col = 0
            while col < w {
                let o  = row * bpr + col * 4
                let rv = Int(px[o + rOff])
                let gv = Int(px[o + gOff])
                let bv = Int(px[o + bOff])
                // Rec. 709 luma
                let lv = min(Int((0.2126 * Float(rv) + 0.7152 * Float(gv) + 0.0722 * Float(bv)).rounded()), 255)
                r[rv] += 1
                g[gv] += 1
                b[bv] += 1
                y[lv] += 1
                total += 1
                col += step
            }
            row += step
        }

        guard total > 0 else { return nil }
        let peak = Float(max(r.max() ?? 1, g.max() ?? 1, b.max() ?? 1, 1))
        let scale = 1.0 / peak
        return HistogramData(
            red:   r.map { Float($0) * scale },
            green: g.map { Float($0) * scale },
            blue:  b.map { Float($0) * scale },
            luma:  y.map { Float($0) * scale }
        )
    }
}
