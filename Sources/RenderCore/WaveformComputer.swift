import CoreVideo
import Foundation

/// Per-column luma distribution density map used for a waveform scope display.
///
/// `density` is a flat array of `columns × 256` Floats.
/// Index = `col * 256 + bin`, where bin 0 = black (luma 0) and bin 255 = white.
/// Values are normalized 0…1 relative to each column's peak count.
public struct WaveformData: Sendable {
    public let columns: Int
    public let density: [Float]

    public func value(column: Int, bin: Int) -> Float {
        guard column >= 0, column < columns, bin >= 0, bin < 256 else { return 0 }
        return density[column * 256 + bin]
    }
}

public enum WaveformComputer {
    private static let numColumns = 256
    private static let numBins    = 256
    private static let rowStep    = 8   // sample every 8th row — keeps 4K under ~3 ms

    public static func compute(from pixelBuffer: CVPixelBuffer) -> WaveformData? {
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
    ) -> WaveformData? {
        CVPixelBufferLockBaseAddress(buf, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buf, .readOnly) }
        guard let ptr = CVPixelBufferGetBaseAddress(buf) else { return nil }

        let w   = CVPixelBufferGetWidth(buf)
        let h   = CVPixelBufferGetHeight(buf)
        let bpr = CVPixelBufferGetBytesPerRow(buf)
        let px  = ptr.assumingMemoryBound(to: UInt8.self)

        let cols = numColumns
        let bins = numBins

        // Precompute column mapping to avoid per-pixel integer division.
        let colMap = (0..<w).map { min($0 * cols / max(w, 1), cols - 1) }

        var counts     = [Int](repeating: 0, count: cols * bins)
        var colSamples = [Int](repeating: 0, count: cols)

        var row = 0
        while row < h {
            for col in 0..<w {
                let o  = row * bpr + col * 4
                let rv = Int(px[o + rOff])
                let gv = Int(px[o + gOff])
                let bv = Int(px[o + bOff])
                // Rec. 709 luma
                let lv = min(
                    Int((0.2126 * Float(rv) + 0.7152 * Float(gv) + 0.0722 * Float(bv)).rounded()),
                    255
                )
                let c = colMap[col]
                counts[c * bins + lv] += 1
                colSamples[c] += 1
            }
            row += rowStep
        }

        // Normalize each column relative to its own peak count.
        var density = [Float](repeating: 0, count: cols * bins)
        for c in 0..<cols {
            guard colSamples[c] > 0 else { continue }
            let base  = c * bins
            var peak  = 0
            for b in 0..<bins { if counts[base + b] > peak { peak = counts[base + b] } }
            guard peak > 0 else { continue }
            let scale = 1.0 / Float(peak)
            for b in 0..<bins {
                density[base + b] = Float(counts[base + b]) * scale
            }
        }

        return WaveformData(columns: cols, density: density)
    }
}
