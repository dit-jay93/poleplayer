import Foundation

// MARK: - Public Types

/// EXR 파일에서 읽은 단일 채널의 메타데이터.
public struct EXRChannelInfo: Equatable, Sendable {
    public let name: String

    public enum PixelType: Int32, Sendable {
        case uint  = 0
        case half  = 1
        case float = 2
    }
    public let pixelType: PixelType

    /// 레이어 이름: "diffuse.R" → "diffuse", "R" → ""
    public var layerName: String {
        guard let dot = name.lastIndex(of: ".") else { return "" }
        return String(name[name.startIndex..<dot])
    }

    /// 채널 단축 이름: "diffuse.R" → "R", "R" → "R"
    public var shortName: String {
        guard let dot = name.lastIndex(of: ".") else { return name }
        return String(name[name.index(after: dot)...])
    }
}

/// EXR 파일의 헤더에서 추출한 정보.
public struct EXRInfo: Equatable, Sendable {
    /// 헤더에 선언된 채널 전체 목록 (알파벳 순 정렬).
    public let channels: [EXRChannelInfo]

    /// 멀티파트 EXR 여부.
    public let isMultiPart: Bool

    /// 채널을 레이어별로 그룹핑한 딕셔너리.
    /// Key "" = 기본 레이어 (R, G, B, A, Z 등).
    public var groupedByLayer: [String: [EXRChannelInfo]] {
        Dictionary(grouping: channels, by: \.layerName)
    }

    /// 레이어 이름 목록 (기본 레이어 "" 포함, 정렬됨).
    public var layerNames: [String] {
        Array(Set(channels.map(\.layerName))).sorted { a, b in
            if a.isEmpty { return true }
            if b.isEmpty { return false }
            return a < b
        }
    }

    /// 채널이 없거나 파싱 실패한 경우.
    public var isEmpty: Bool { channels.isEmpty }
}

// MARK: - Inspector

/// EXR 파일 헤더를 파싱해 채널 정보를 반환합니다.
///
/// 외부 라이브러리 없이 순수 Swift로 OpenEXR 헤더 스펙을 구현합니다.
/// 픽셀 데이터는 읽지 않으므로 매우 빠릅니다 (헤더만 메모리에 로드).
public enum EXRInspector {

    /// URL에서 EXR 헤더를 파싱합니다. 실패하면 nil 반환.
    public static func inspect(url: URL) -> EXRInfo? {
        // 헤더만 읽어도 되지만 mappedIfSafe는 OS가 필요할 때 로드함 → 효율적
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return inspect(data: data)
    }

    /// 데이터에서 EXR 헤더를 파싱합니다.
    public static func inspect(data: Data) -> EXRInfo? {
        guard data.count >= 8 else { return nil }

        // ── Magic check ──────────────────────────────────────────────────
        // OpenEXR magic: little-endian uint32 = 0x01312F76 (= 20000630)
        // 파일 바이트 순서: 0x76 0x2F 0x31 0x01
        guard data[0] == 0x76, data[1] == 0x2F,
              data[2] == 0x31, data[3] == 0x01 else { return nil }

        // ── Version / flags ──────────────────────────────────────────────
        let versionWord = data.exrU32LE(at: 4)
        let isMultiPart = (versionWord & 0x1000) != 0

        // ── Parse first-part header ──────────────────────────────────────
        var offset = 8
        var channels: [EXRChannelInfo] = []

        while offset < data.count {
            guard let attrName = data.exrString(at: &offset) else { break }
            if attrName.isEmpty { break }   // 헤더 끝 (빈 이름 = null byte)

            guard let attrType = data.exrString(at: &offset) else { break }

            guard offset + 4 <= data.count else { break }
            let attrSize = Int(data.exrU32LE(at: offset))
            offset += 4

            guard offset + attrSize <= data.count else { break }

            if attrName == "channels" && attrType == "chlist" {
                channels = parseChlist(data: data, from: offset, size: attrSize)
            }

            offset += attrSize
        }

        guard !channels.isEmpty else { return nil }

        let sorted = channels.sorted { $0.name < $1.name }
        return EXRInfo(channels: sorted, isMultiPart: isMultiPart)
    }

    // MARK: - chlist attribute parser

    private static func parseChlist(data: Data, from start: Int, size: Int) -> [EXRChannelInfo] {
        var result: [EXRChannelInfo] = []
        var offset = start
        let end = start + size

        while offset < end {
            guard let name = data.exrString(at: &offset), !name.isEmpty else { break }

            // pixelType (4 bytes) + pLinear (1) + reserved (3) + xSampling (4) + ySampling (4) = 16
            guard offset + 16 <= end else { break }

            let typeRaw = Int32(bitPattern: data.exrU32LE(at: offset))
            offset += 4   // pixelType
            offset += 4   // pLinear (1) + reserved (3)
            offset += 4   // xSampling
            offset += 4   // ySampling

            let pt: EXRChannelInfo.PixelType
            switch typeRaw {
            case 0:  pt = .uint
            case 2:  pt = .float
            default: pt = .half
            }

            result.append(EXRChannelInfo(name: name, pixelType: pt))
        }

        return result
    }
}

// MARK: - Data helpers (file-private)

private extension Data {
    /// Little-endian uint32 at byte offset (no bounds check guards above ensure safety).
    func exrU32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return self[offset..<(offset + 4)].withUnsafeBytes { ptr in
            // Safe unaligned little-endian load
            let b0 = UInt32(ptr[0])
            let b1 = UInt32(ptr[1]) << 8
            let b2 = UInt32(ptr[2]) << 16
            let b3 = UInt32(ptr[3]) << 24
            return b0 | b1 | b2 | b3
        }
    }

    /// Reads a null-terminated ASCII/UTF-8 string and advances `offset` past the null.
    /// Returns "" if the byte at `offset` is already null (end of list).
    func exrString(at offset: inout Int) -> String? {
        guard offset < count else { return nil }
        if self[offset] == 0 {
            offset += 1
            return ""   // empty string = terminator
        }
        var end = offset
        while end < count && self[end] != 0 { end += 1 }
        guard end < count else { return nil }
        let str = String(bytes: self[offset..<end], encoding: .utf8)
            ?? String(bytes: self[offset..<end], encoding: .isoLatin1)
            ?? ""
        offset = end + 1    // skip past null
        return str
    }
}
