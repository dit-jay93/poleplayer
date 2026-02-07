import CoreGraphics
import RenderCore
import Review

enum ExportOverlayBuilder {
    static func overlayImage(
        size: CGSize,
        hud: HUDOverlayData?,
        annotations: [AnnotationRecord]
    ) -> CGImage? {
        if hud == nil && annotations.isEmpty {
            return nil
        }
        let overlayAnnotations = mapAnnotations(annotations)
        if hud == nil && overlayAnnotations.isEmpty {
            return nil
        }
        let payload = OverlayPayload(hud: hud, annotations: overlayAnnotations)
        let composer = OverlayComposer()
        return composer.renderImage(size: size, payload: payload)
    }

    private static func mapAnnotation(_ record: AnnotationRecord) -> OverlayAnnotation? {
        let style = OverlayStyle(
            strokeColor: record.style.strokeColor,
            fillColor: record.style.fillColor,
            strokeWidth: record.style.strokeWidth
        )
        switch record.geometry {
        case .pen(let points):
            let overlayPoints = points.map { OverlayPoint(x: $0.x, y: $0.y) }
            return OverlayAnnotation(type: .pen, geometry: .pen(points: overlayPoints), style: style)
        case .rect(let bounds):
            let rect = OverlayRect(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height)
            return OverlayAnnotation(type: .rect, geometry: .rect(bounds: rect), style: style)
        case .circle(let bounds):
            let rect = OverlayRect(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height)
            return OverlayAnnotation(type: .circle, geometry: .circle(bounds: rect), style: style)
        case .arrow(let start, let end):
            let s = OverlayPoint(x: start.x, y: start.y)
            let e = OverlayPoint(x: end.x, y: end.y)
            return OverlayAnnotation(type: .arrow, geometry: .arrow(start: s, end: e), style: style)
        case .text(let anchor, let text):
            let a = OverlayPoint(x: anchor.x, y: anchor.y)
            return OverlayAnnotation(type: .text, geometry: .text(anchor: a, text: text), style: style)
        }
    }

    static func mapAnnotations(_ records: [AnnotationRecord]) -> [OverlayAnnotation] {
        return records.compactMap { mapAnnotation($0) }
    }
}
