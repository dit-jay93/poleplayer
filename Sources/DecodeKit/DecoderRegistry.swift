import Foundation

/// 플러그인 디코더를 등록하고, 파일 확장자 + canOpen 기반으로 자동 선택하는 레지스트리.
///
/// 앱 시작 시 `DecoderRegistry.shared`가 초기화되면서 빌트인 플러그인이 등록됩니다.
/// 서드파티 플러그인은 `register(_:)` 호출로 추가할 수 있습니다.
public final class DecoderRegistry: @unchecked Sendable {

    public static let shared: DecoderRegistry = {
        let r = DecoderRegistry()
        r.register(AVFoundationDecoder.self)
        r.register(ARRIRawDecoder.self)
        r.register(RedDecoder.self)
        return r
    }()

    private var plugins: [any DecoderPlugin.Type] = []
    private let lock = NSLock()

    private init() {}

    // MARK: - Registration

    /// 플러그인 타입을 등록합니다. 동일 pluginID가 이미 등록되어 있으면 무시합니다.
    public func register(_ plugin: any DecoderPlugin.Type) {
        lock.lock()
        defer { lock.unlock() }
        guard !plugins.contains(where: { $0.pluginID == plugin.pluginID }) else { return }
        plugins.append(plugin)
    }

    // MARK: - Selection

    /// 등록된 플러그인 목록을 반환합니다 (읽기 전용 스냅샷).
    public var registeredPlugins: [any DecoderPlugin.Type] {
        lock.lock()
        defer { lock.unlock() }
        return plugins
    }

    /// 주어진 descriptor에 대해 가장 적합한 플러그인 타입을 반환합니다.
    /// 우선순위: 확장자 매칭 → canOpen 검사 → 등록 순서.
    public func preferredPlugin(for descriptor: AssetDescriptor) -> (any DecoderPlugin.Type)? {
        lock.lock()
        defer { lock.unlock() }
        let ext = descriptor.url.pathExtension.lowercased()
        return plugins
            .filter { $0.supportedExtensions.contains(ext) }
            .first { $0.canOpen(descriptor) }
    }

    // MARK: - Factory

    /// descriptor에 맞는 플러그인을 찾아 인스턴스를 생성해 반환합니다.
    /// 플러그인을 찾지 못하면 `DecoderRegistryError.noPluginFound`를 throw합니다.
    /// 플러그인 init이 throw하면 (예: SDK 미설치) 그 에러가 전파됩니다.
    public func makeDecoder(for descriptor: AssetDescriptor) throws -> any DecoderPlugin {
        guard let type = preferredPlugin(for: descriptor) else {
            throw DecoderRegistryError.noPluginFound(descriptor.url.pathExtension)
        }
        return try type.init(asset: descriptor)
    }
}

// MARK: - Registry Errors

public enum DecoderRegistryError: LocalizedError {
    case noPluginFound(String)

    public var errorDescription: String? {
        switch self {
        case .noPluginFound(let ext):
            return "No decoder plugin available for .\(ext) files."
        }
    }
}
