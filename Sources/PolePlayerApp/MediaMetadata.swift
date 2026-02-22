import AVFoundation
import CoreMedia
import Foundation
import ImageIO

// MARK: - Model

public struct MediaMetadata: Equatable, Sendable {
    public var fileName:       String = ""
    public var fileSize:       String = ""
    public var container:      String = ""
    public var videoCodec:     String = ""
    public var resolution:     String = ""
    public var frameRate:      String = ""
    public var duration:       String = ""
    public var videoBitRate:   String = ""
    public var bitDepth:       String = ""
    public var colorSpace:     String = ""
    public var hdrMode:        String = ""
    public var audioCodec:     String = ""
    public var audioChannels:  String = ""
    public var audioSampleRate: String = ""
    public var audioBitRate:   String = ""

    public static let empty = MediaMetadata()
}

// MARK: - Extractor

enum MediaMetadataExtractor {

    /// 비디오 파일에서 메타데이터를 비동기 추출합니다
    static func extract(from url: URL) async -> MediaMetadata {
        var meta = MediaMetadata()
        meta.fileName  = url.lastPathComponent
        meta.container = url.pathExtension.uppercased()
        meta.fileSize  = fileSizeString(url)

        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])

        // Duration
        if let duration = try? await asset.load(.duration) {
            meta.duration = formatDuration(duration)
        }

        // Video track
        if let tracks = try? await asset.loadTracks(withMediaType: .video),
           let track = tracks.first {
            await extractVideoTrack(track, into: &meta)
        }

        // Audio track
        if let tracks = try? await asset.loadTracks(withMediaType: .audio),
           let track = tracks.first {
            await extractAudioTrack(track, into: &meta)
        }

        return meta
    }

    /// 이미지 파일에서 메타데이터를 추출합니다 (동기)
    static func extractImage(from url: URL) -> MediaMetadata {
        var meta = MediaMetadata()
        meta.fileName  = url.lastPathComponent
        meta.container = url.pathExtension.uppercased()
        meta.fileSize  = fileSizeString(url)

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props  = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return meta }

        let w = props[kCGImagePropertyPixelWidth]  as? Int ?? 0
        let h = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        if w > 0 && h > 0 { meta.resolution = "\(w) × \(h)" }

        if let depth = props[kCGImagePropertyDepth] as? Int {
            meta.bitDepth = "\(depth)-bit"
        }
        if let cs = props[kCGImagePropertyColorModel] as? String {
            meta.colorSpace = cs
        }
        if let dpi = props[kCGImagePropertyDPIWidth] as? Double {
            meta.frameRate = String(format: "%.0f dpi", dpi)
        }

        // EXR specific
        if let exr = props["EXRProperties" as CFString] as? [CFString: Any],
           let ch = exr["Channels" as CFString] {
            meta.audioChannels = "\(ch) channels"
        }

        return meta
    }

    // MARK: - Video Helpers

    private static func extractVideoTrack(_ track: AVAssetTrack, into meta: inout MediaMetadata) async {
        if let size = try? await track.load(.naturalSize) {
            meta.resolution = "\(Int(size.width)) × \(Int(size.height))"
        }
        if let fps = try? await track.load(.nominalFrameRate), fps > 0 {
            meta.frameRate = String(format: "%.3f fps", fps)
        }
        if let br = try? await track.load(.estimatedDataRate), br > 0 {
            meta.videoBitRate = formatBitRate(br)
        }
        if let descs = try? await track.load(.formatDescriptions),
           let desc = descs.first {
            let subType = CMFormatDescriptionGetMediaSubType(desc)
            meta.videoCodec = fourCC(subType)

            if let exts = CMFormatDescriptionGetExtensions(desc) as? [String: Any] {
                if let primaries = exts[kCMFormatDescriptionExtension_ColorPrimaries as String] as? String {
                    meta.colorSpace = friendlyColorSpace(primaries)
                }
                if let transfer = exts[kCMFormatDescriptionExtension_TransferFunction as String] as? String {
                    meta.hdrMode = friendlyTransfer(transfer)
                }
                if let depth = exts[kCMFormatDescriptionExtension_Depth as String] as? Int {
                    meta.bitDepth = "\(depth)-bit"
                }
            }
        }
    }

    private static func extractAudioTrack(_ track: AVAssetTrack, into meta: inout MediaMetadata) async {
        if let br = try? await track.load(.estimatedDataRate), br > 0 {
            meta.audioBitRate = formatBitRate(br)
        }
        if let descs = try? await track.load(.formatDescriptions),
           let desc = descs.first {
            if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee {
                meta.audioChannels  = "\(Int(asbd.mChannelsPerFrame))ch"
                meta.audioSampleRate = String(format: "%.1f kHz", asbd.mSampleRate / 1000)
            }
            let subType = CMFormatDescriptionGetMediaSubType(desc)
            meta.audioCodec = fourCC(subType)
        }
    }

    // MARK: - Formatting

    private static func fileSizeString(_ url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size  = attrs[.size] as? Int64 else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private static func formatDuration(_ time: CMTime) -> String {
        guard time.isValid, time.seconds.isFinite else { return "" }
        let total = Int(time.seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private static func formatBitRate(_ bps: Float) -> String {
        if bps >= 1_000_000 { return String(format: "%.1f Mbps", bps / 1_000_000) }
        return String(format: "%.0f kbps", bps / 1_000)
    }

    private static func fourCC(_ value: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >>  8) & 0xFF),
            UInt8( value        & 0xFF),
        ]
        let str = String(bytes: bytes, encoding: .ascii)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return str.isEmpty ? String(format: "0x%08X", value) : str
    }

    private static func friendlyColorSpace(_ raw: String) -> String {
        switch raw {
        case "ITU_R_709_2":     return "Rec. 709"
        case "ITU_R_2020":      return "Rec. 2020"
        case "P3_D65":          return "P3-D65"
        case "SMPTE_C":         return "SMPTE-C"
        case "EBU_3213":        return "EBU 3213"
        default:                return raw
        }
    }

    private static func friendlyTransfer(_ raw: String) -> String {
        switch raw {
        case "ITU_R_709_2":               return "SDR (Rec. 709)"
        case "SMPTE_ST_2084_PQ":          return "HDR PQ (ST 2084)"
        case "ITU_R_2100_HLG":            return "HDR HLG"
        case "Linear":                    return "Linear"
        case "sRGB":                      return "sRGB"
        default:                          return raw
        }
    }
}
