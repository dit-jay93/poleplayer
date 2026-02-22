import CoreGraphics
import Foundation

/// Basic DPX (SMPTE 268M) decoder.
///
/// Supports:
/// - 10-bit RGB, Packing Method A (most common production format)
/// - 8-bit RGB (fallback)
/// - Big-endian ("SDPX") and little-endian ("XPDS") byte order
/// - Cineon log → display-gamma conversion (transfer characteristic 1)
///
/// Limitations (V1.5):
/// - Single image element only (element 0)
/// - Packed (packing=0) and 12/16-bit formats not supported
public enum DPXDecoder {

    public enum DPXError: Error, LocalizedError {
        case invalidFile
        case invalidDimensions
        case unsupportedFormat(String)
        case truncatedData

        public var errorDescription: String? {
            switch self {
            case .invalidFile:               return "Not a valid DPX file."
            case .invalidDimensions:         return "DPX file has invalid dimensions."
            case .unsupportedFormat(let s):  return "Unsupported DPX format: \(s)"
            case .truncatedData:             return "DPX file is truncated."
            }
        }
    }

    // MARK: - Public API

    public static func decode(url: URL) throws -> CGImage {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try decode(data: data)
    }

    public static func decode(data: Data) throws -> CGImage {
        guard data.count >= 2048 else { throw DPXError.invalidFile }

        // ── Endianness ──────────────────────────────────────────────
        let magic = data.dpxU32(at: 0, bigEndian: true)
        let be: Bool
        switch magic {
        case 0x53445058: be = true    // "SDPX" — big-endian
        case 0x58504453: be = false   // "XPDS" — little-endian
        default:         throw DPXError.invalidFile
        }

        // ── Geometry ────────────────────────────────────────────────
        let width  = Int(data.dpxU32(at: 772, bigEndian: be))
        let height = Int(data.dpxU32(at: 776, bigEndian: be))
        guard width > 0, height > 0, width <= 16384, height <= 16384 else {
            throw DPXError.invalidDimensions
        }

        // ── Image element 0 (starts at offset 780) ──────────────────
        let descriptor  = data[800]   // 50=RGB, 51=RGBA
        let transfer    = data[801]   // 1=printing density (Cineon log), 5=linear
        let bitDepth    = data[803]   // 8 or 10
        let packing     = data.dpxU16(at: 804, bigEndian: be)  // 0=packed,1=filled A,2=filled B
        let rawEolPad   = data.dpxU32(at: 812, bigEndian: be)
        let eolPad      = rawEolPad == 0xFFFF_FFFF ? 0 : Int(rawEolPad)

        // Pixel data offset: prefer element-level, fall back to file-level
        let elemOff = Int(data.dpxU32(at: 808, bigEndian: be))
        let fileOff = Int(data.dpxU32(at:   4, bigEndian: be))
        let pixelOffset: Int
        if elemOff >= 2048 && elemOff < data.count {
            pixelOffset = elemOff
        } else if fileOff >= 2048 && fileOff < data.count {
            pixelOffset = fileOff
        } else {
            pixelOffset = 2048
        }

        // Only handle RGB / RGBA
        guard descriptor == 50 || descriptor == 51 else {
            throw DPXError.unsupportedFormat("descriptor=\(descriptor)")
        }

        // ── Decode ──────────────────────────────────────────────────
        switch bitDepth {
        case 10:
            guard packing == 1 || packing == 2 else {
                throw DPXError.unsupportedFormat("10-bit packing=\(packing) not supported")
            }
            return try decode10bit(data: data, width: width, height: height,
                                   pixelOffset: pixelOffset, eolPad: eolPad,
                                   bigEndian: be, transfer: transfer)
        case 8:
            let channels = descriptor == 51 ? 4 : 3
            return try decode8bit(data: data, width: width, height: height,
                                  pixelOffset: pixelOffset, eolPad: eolPad,
                                  channels: channels)
        default:
            throw DPXError.unsupportedFormat("bitDepth=\(bitDepth)")
        }
    }

    // MARK: - 10-bit RGB Filled A/B

    /// Decodes 10-bit RGB where each pixel occupies one 32-bit word:
    ///   bits 31..22 = R, 21..12 = G, 11..2 = B, 1..0 = pad  (big-endian word)
    private static func decode10bit(
        data: Data, width: Int, height: Int,
        pixelOffset: Int, eolPad: Int,
        bigEndian: Bool, transfer: UInt8
    ) throws -> CGImage {
        let bytesPerRow = width * 4 + eolPad
        let required    = pixelOffset + height * bytesPerRow
        guard data.count >= required else { throw DPXError.truncatedData }

        // Precompute 10→8 LUT (Cineon log or linear)
        let lut = buildLUT10(isCineonLog: transfer == 1 || transfer == 0)

        var out = [UInt8](repeating: 255, count: width * height * 4)

        for row in 0..<height {
            let rowBase = pixelOffset + row * bytesPerRow
            for col in 0..<width {
                let wordOff = rowBase + col * 4
                let word = data.dpxU32(at: wordOff, bigEndian: bigEndian)
                let r = Int((word >> 22) & 0x3FF)
                let g = Int((word >> 12) & 0x3FF)
                let b = Int((word >>  2) & 0x3FF)
                let idx = (row * width + col) * 4
                out[idx + 0] = lut[r]
                out[idx + 1] = lut[g]
                out[idx + 2] = lut[b]
                // out[idx + 3] = 255 already set
            }
        }
        return try makeCGImage(pixels: out, width: width, height: height)
    }

    // MARK: - 8-bit RGB

    private static func decode8bit(
        data: Data, width: Int, height: Int,
        pixelOffset: Int, eolPad: Int, channels: Int
    ) throws -> CGImage {
        let srcBytesPerRow = width * channels + eolPad
        let required       = pixelOffset + height * srcBytesPerRow
        guard data.count >= required else { throw DPXError.truncatedData }

        var out = [UInt8](repeating: 255, count: width * height * 4)

        for row in 0..<height {
            let rowBase = pixelOffset + row * srcBytesPerRow
            for col in 0..<width {
                let src = rowBase + col * channels
                let dst = (row * width + col) * 4
                out[dst + 0] = data[src + 0]
                out[dst + 1] = data[src + 1]
                out[dst + 2] = data[src + 2]
            }
        }
        return try makeCGImage(pixels: out, width: width, height: height)
    }

    // MARK: - Helpers

    /// 1024-entry LUT: 10-bit value → 8-bit display value.
    ///
    /// For Cineon log (printing density), applies the standard Cineon to
    /// display-linear transform with gamma 2.2, so the image looks correct
    /// on a standard monitor (not color-managed HDR output).
    ///
    /// For linear DPX, applies simple linear scale.
    private static func buildLUT10(isCineonLog: Bool) -> [UInt8] {
        var lut = [UInt8](repeating: 0, count: 1024)
        for i in 0..<1024 {
            let display: Double
            if isCineonLog {
                // Cineon: code 685 = 0.18 scene linear (reference gray)
                let linear  = pow(10.0, (Double(i) - 685.0) / 300.0) * 0.18
                display = linear > 0 ? pow(min(linear / 0.18, 1.0), 1.0 / 2.2) : 0
            } else {
                display = Double(i) / 1023.0
            }
            lut[i] = UInt8(min(max(display, 0.0), 1.0) * 255.0)
        }
        return lut
    }

    private static func makeCGImage(pixels: [UInt8], width: Int, height: Int) throws -> CGImage {
        let pixelData = Data(pixels)
        guard let provider = CGDataProvider(data: pixelData as CFData),
              let image = CGImage(
                width: width, height: height,
                bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                provider: provider, decode: nil,
                shouldInterpolate: true, intent: .defaultIntent
              ) else {
            throw DPXError.truncatedData
        }
        return image
    }
}

// MARK: - Data extensions (file-private)

private extension Data {
    func dpxU32(at offset: Int, bigEndian: Bool) -> UInt32 {
        guard offset + 3 < count else { return 0 }
        var raw: UInt32 = 0
        Swift.withUnsafeMutableBytes(of: &raw) { (ptr: UnsafeMutableRawBufferPointer) in
            self[offset..<(offset + 4)].copyBytes(to: ptr)
        }
        // Mac is little-endian; if file is big-endian, byte-swap
        return bigEndian ? raw.byteSwapped : raw
    }

    func dpxU16(at offset: Int, bigEndian: Bool) -> UInt16 {
        guard offset + 1 < count else { return 0 }
        var raw: UInt16 = 0
        Swift.withUnsafeMutableBytes(of: &raw) { (ptr: UnsafeMutableRawBufferPointer) in
            self[offset..<(offset + 2)].copyBytes(to: ptr)
        }
        return bigEndian ? raw.byteSwapped : raw
    }
}
