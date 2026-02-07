import Foundation
import simd

public struct OverlayPoint: Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct OverlayRect: Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum OverlayAnnotationType: String {
    case pen
    case rect
    case circle
    case arrow
    case text
}

public struct OverlayStyle: Equatable {
    public let strokeColor: SIMD4<Double>
    public let fillColor: SIMD4<Double>
    public let strokeWidth: Double

    public init(strokeColor: SIMD4<Double>, fillColor: SIMD4<Double>, strokeWidth: Double) {
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.strokeWidth = strokeWidth
    }
}

public enum OverlayGeometry: Equatable {
    case pen(points: [OverlayPoint])
    case rect(bounds: OverlayRect)
    case circle(bounds: OverlayRect)
    case arrow(start: OverlayPoint, end: OverlayPoint)
    case text(anchor: OverlayPoint, text: String)
}

public struct OverlayAnnotation: Equatable {
    public let type: OverlayAnnotationType
    public let geometry: OverlayGeometry
    public let style: OverlayStyle

    public init(type: OverlayAnnotationType, geometry: OverlayGeometry, style: OverlayStyle) {
        self.type = type
        self.geometry = geometry
        self.style = style
    }
}

public struct OverlayPayload: Equatable {
    public let hud: HUDOverlayData?
    public let annotations: [OverlayAnnotation]

    public init(hud: HUDOverlayData?, annotations: [OverlayAnnotation]) {
        self.hud = hud
        self.annotations = annotations
    }
}
