import Foundation

/// ARRIRAW 디코더 플러그인 스텁.
///
/// 실제 디코딩은 ARRI SDK(libdcr / ARRI Reference Tool)가 필요합니다.
/// SDK 없이 파일을 열면 명확한 에러 메시지를 표시합니다.
///
/// SDK 연동 방법:
///   1. ARRI SDK를 번들에 포함하거나 링크합니다.
///   2. `ARRIRawSDK.isAvailable` 검사 후 실제 디코딩 경로를 구현합니다.
///   3. `DecoderRegistry.shared.register(ARRIRawDecoder.self)`는 이미 호출됩니다.
public final class ARRIRawDecoder: DecoderPlugin {

    public static let pluginID = "decode.arriraw"
    public static let displayName = "ARRIRAW"

    /// 지원 확장자.
    /// .ari  — ARRI MXF-wrapped RAW
    /// .arx  — ARRI RAW (newer container)
    public static let supportedExtensions = ["ari", "arx"]

    public static func canOpen(_ asset: AssetDescriptor) -> Bool {
        supportedExtensions.contains(asset.url.pathExtension.lowercased())
    }

    public init(asset: AssetDescriptor) throws {
        throw ARRIRawDecoderError.sdkNotInstalled
    }

    public func prepare() {}

    public func decodeFrame(_ request: FrameRequest) throws -> DecodedFrame {
        throw ARRIRawDecoderError.sdkNotInstalled
    }

    public func prefetch(frames: [Int]) {}

    public func close() {}
}

public enum ARRIRawDecoderError: LocalizedError {
    case sdkNotInstalled

    public var errorDescription: String? {
        "ARRIRAW decoding requires the ARRI SDK (libdcr). " +
        "Install the ARRI Reference Tool and place the SDK framework in the app bundle, then rebuild."
    }
}
