import Foundation

/// RED R3D 디코더 플러그인 스텁.
///
/// 실제 디코딩은 RED SDK(REDCODE SDK / R3D SDK)가 필요합니다.
/// SDK 없이 파일을 열면 명확한 에러 메시지를 표시합니다.
///
/// SDK 연동 방법:
///   1. RED Digital Cinema에서 R3D SDK를 받아 번들에 포함합니다.
///   2. `RedSDK.isAvailable` 검사 후 실제 디코딩 경로를 구현합니다.
///   3. `DecoderRegistry.shared.register(RedDecoder.self)`는 이미 호출됩니다.
public final class RedDecoder: DecoderPlugin {

    public static let pluginID = "decode.red.r3d"
    public static let displayName = "RED R3D"

    /// 지원 확장자.
    /// .r3d  — RED RAW
    public static let supportedExtensions = ["r3d"]

    public static func canOpen(_ asset: AssetDescriptor) -> Bool {
        supportedExtensions.contains(asset.url.pathExtension.lowercased())
    }

    public init(asset: AssetDescriptor) throws {
        throw RedDecoderError.sdkNotInstalled
    }

    public func prepare() {}

    public func decodeFrame(_ request: FrameRequest) throws -> DecodedFrame {
        throw RedDecoderError.sdkNotInstalled
    }

    public func prefetch(frames: [Int]) {}

    public func close() {}
}

public enum RedDecoderError: LocalizedError {
    case sdkNotInstalled

    public var errorDescription: String? {
        "R3D decoding requires the RED SDK (REDCODE SDK). " +
        "Obtain the SDK from RED Digital Cinema and rebuild PolePlayer with the framework linked."
    }
}
