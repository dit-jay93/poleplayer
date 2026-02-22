import Foundation
import PlayerCore

// MARK: - Grid Layout

/// 멀티클립 그리드 레이아웃 옵션.
public enum GridLayout: String, CaseIterable, Sendable {
    case single = "1×1"
    case twoUp  = "1×2"   // 2열 1행
    case quad   = "2×2"   // 2열 2행

    var slotCount: Int {
        switch self {
        case .single: return 1
        case .twoUp:  return 2
        case .quad:   return 4
        }
    }

    var columns: Int {
        switch self {
        case .single: return 1
        case .twoUp, .quad: return 2
        }
    }

    var sfSymbol: String {
        switch self {
        case .single: return "rectangle"
        case .twoUp:  return "rectangle.split.2x1"
        case .quad:   return "square.grid.2x2"
        }
    }
}

// MARK: - Grid Slot

/// 그리드 한 셀의 상태 — 독립적인 PlayerController를 내장합니다.
@MainActor
public final class GridSlot: ObservableObject, Identifiable {
    public let id: UUID
    public let controller: PlayerController
    @Published public private(set) var url: URL? = nil

    public init() {
        id = UUID()
        controller = PlayerController()
    }

    public func open(url: URL) {
        self.url = url
        controller.openVideo(url: url)
    }

    public func clear() {
        url = nil
        controller.clear()
    }

    public var label: String {
        url?.deletingPathExtension().lastPathComponent ?? ""
    }

    public var filename: String {
        url?.lastPathComponent ?? ""
    }
}
