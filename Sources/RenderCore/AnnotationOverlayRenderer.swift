import AppKit
import CoreGraphics

public final class AnnotationOverlayRenderer {
    public init() {}

    public func draw(in context: CGContext, size: CGSize, annotations: [OverlayAnnotation]) {
        let graphics = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics

        for annotation in annotations {
            draw(annotation: annotation, size: size)
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    private func draw(annotation: OverlayAnnotation, size: CGSize) {
        switch annotation.geometry {
        case .pen(let points):
            drawPen(points: points, style: annotation.style, size: size)
        case .rect(let bounds):
            drawRect(bounds: bounds, style: annotation.style, size: size)
        case .circle(let bounds):
            drawCircle(bounds: bounds, style: annotation.style, size: size)
        case .arrow(let start, let end):
            drawArrow(start: start, end: end, style: annotation.style, size: size)
        case .text(let anchor, let text):
            drawText(anchor: anchor, text: text, style: annotation.style, size: size)
        }
    }

    private func drawPen(points: [OverlayPoint], style: OverlayStyle, size: CGSize) {
        guard points.count > 1 else { return }
        let path = NSBezierPath()
        let first = denormalize(points[0], size: size)
        path.move(to: first)
        for point in points.dropFirst() {
            path.line(to: denormalize(point, size: size))
        }
        path.lineWidth = style.strokeWidth
        color(from: style.strokeColor).setStroke()
        path.stroke()
    }

    private func drawRect(bounds: OverlayRect, style: OverlayStyle, size: CGSize) {
        let rect = denormalize(bounds, size: size)
        let path = NSBezierPath(rect: rect)
        color(from: style.fillColor).setFill()
        path.fill()
        path.lineWidth = style.strokeWidth
        color(from: style.strokeColor).setStroke()
        path.stroke()
    }

    private func drawCircle(bounds: OverlayRect, style: OverlayStyle, size: CGSize) {
        let rect = denormalize(bounds, size: size)
        let path = NSBezierPath(ovalIn: rect)
        color(from: style.fillColor).setFill()
        path.fill()
        path.lineWidth = style.strokeWidth
        color(from: style.strokeColor).setStroke()
        path.stroke()
    }

    private func drawArrow(start: OverlayPoint, end: OverlayPoint, style: OverlayStyle, size: CGSize) {
        let startPoint = denormalize(start, size: size)
        let endPoint = denormalize(end, size: size)
        let path = NSBezierPath()
        path.move(to: startPoint)
        path.line(to: endPoint)
        path.lineWidth = style.strokeWidth
        color(from: style.strokeColor).setStroke()
        path.stroke()

        let angle = atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
        let arrowLength = max(8, style.strokeWidth * 3)
        let arrowAngle = CGFloat.pi / 6

        let point1 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle - arrowAngle),
            y: endPoint.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: endPoint.x - arrowLength * cos(angle + arrowAngle),
            y: endPoint.y - arrowLength * sin(angle + arrowAngle)
        )

        let arrowPath = NSBezierPath()
        arrowPath.move(to: endPoint)
        arrowPath.line(to: point1)
        arrowPath.line(to: point2)
        arrowPath.close()
        color(from: style.strokeColor).setFill()
        arrowPath.fill()
    }

    private func drawText(anchor: OverlayPoint, text: String, style: OverlayStyle, size: CGSize) {
        let point = denormalize(anchor, size: size)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Pretendard-Regular", size: max(12, style.strokeWidth * 4)) ?? NSFont.systemFont(ofSize: 12),
            .foregroundColor: color(from: style.strokeColor)
        ]
        (text as NSString).draw(at: point, withAttributes: attributes)
    }

    private func denormalize(_ point: OverlayPoint, size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func denormalize(_ rect: OverlayRect, size: CGSize) -> CGRect {
        CGRect(
            x: rect.x * size.width,
            y: rect.y * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }

    private func color(from rgba: SIMD4<Double>) -> NSColor {
        NSColor(
            red: CGFloat(rgba.x),
            green: CGFloat(rgba.y),
            blue: CGFloat(rgba.z),
            alpha: CGFloat(rgba.w)
        )
    }
}
