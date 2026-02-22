import CoreVideo
import Foundation

/// 2-D chrominance density map for vectorscope display.
///
/// U axis (horizontal) = Cb, V axis (vertical) = Cr, both in Rec. 709.
/// `density` is a flat `size × size` Float array:
///   index = v_idx * size + u_idx
///   u_idx 0 = Cb –0.5 (left),  size-1 = Cb +0.5 (right)
///   v_idx 0 = Cr –0.5 (bottom), size-1 = Cr +0.5 (top)
/// Values are normalized 0…1 relative to the global peak bin count.
public struct VectorscopeData: Sendable {
    public let size: Int
    public let density: [Float]

    public func value(uIdx: Int, vIdx: Int) -> Float {
        guard uIdx >= 0, uIdx < size, vIdx >= 0, vIdx < size else { return 0 }
        return density[vIdx * size + uIdx]
    }
}

public enum VectorscopeComputer {
    private static let gridSize = 256
    private static let rowStep  = 4   // skip every 4th row for speed
    private static let colStep  = 4   // skip every 4th column — spatial position irrelevant

    public static func compute(from pixelBuffer: CVPixelBuffer) -> VectorscopeData? {
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
    ) -> VectorscopeData? {
        CVPixelBufferLockBaseAddress(buf, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buf, .readOnly) }
        guard let ptr = CVPixelBufferGetBaseAddress(buf) else { return nil }

        let w   = CVPixelBufferGetWidth(buf)
        let h   = CVPixelBufferGetHeight(buf)
        let bpr = CVPixelBufferGetBytesPerRow(buf)
        let px  = ptr.assumingMemoryBound(to: UInt8.self)

        let sz   = gridSize
        let szF  = Float(sz - 1)

        var counts = [Int](repeating: 0, count: sz * sz)
        var peak   = 0

        var row = 0
        while row < h {
            var col = 0
            while col < w {
                let o  = row * bpr + col * 4
                let rf = Float(px[o + rOff]) / 255.0
                let gf = Float(px[o + gOff]) / 255.0
                let bf = Float(px[o + bOff]) / 255.0

                // Rec. 709 YCbCr
                let cb = -0.1146 * rf - 0.3854 * gf + 0.5000 * bf   // –0.5 … +0.5
                let cr =  0.5000 * rf - 0.4542 * gf - 0.0458 * bf   // –0.5 … +0.5

                // Map to grid — u_idx = Cb, v_idx = Cr
                let uIdx = min(max(Int((cb + 0.5) * szF), 0), sz - 1)
                let vIdx = min(max(Int((cr + 0.5) * szF), 0), sz - 1)

                let idx = vIdx * sz + uIdx
                counts[idx] += 1
                if counts[idx] > peak { peak = counts[idx] }

                col += colStep
            }
            row += rowStep
        }

        guard peak > 0 else { return nil }
        let scale = 1.0 / Float(peak)
        let density = counts.map { Float($0) * scale }
        return VectorscopeData(size: sz, density: density)
    }
}
