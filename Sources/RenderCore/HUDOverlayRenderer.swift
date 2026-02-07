import AppKit
import CoreGraphics
import os

public struct HUDOverlayData: Equatable {
    public let timecode: String
    public let frameIndex: Int
    public let fps: Double
    public let resolution: CGSize

    public init(timecode: String, frameIndex: Int, fps: Double, resolution: CGSize) {
        self.timecode = timecode
        self.frameIndex = frameIndex
        self.fps = fps
        self.resolution = resolution
    }
}

public final class HUDOverlayRenderer {
    private let log = Logger(subsystem: "PolePlayer", category: "HUDOverlay")
    private let labelFont: NSFont
    private let valueFont: NSFont
    private let labelColor = NSColor(white: 0.8, alpha: 1.0)
    private let valueColor = NSColor(white: 1.0, alpha: 1.0)
    private let backgroundColor = NSColor(white: 0.0, alpha: 0.65)
    private let paddingX: CGFloat = 10
    private let paddingY: CGFloat = 6
    private let rowSpacing: CGFloat = 6
    private let cornerRadius: CGFloat = 8
    private let margin: CGFloat = 12
    private let labelSpacing: CGFloat = 8

    public init() {
        let label = HUDOverlayRenderer.makeFont(name: "Pretendard-Regular", size: 12)
        let value = HUDOverlayRenderer.makeFont(name: "Pretendard-SemiBold", size: 12)
        if label.familyName != "Pretendard" || value.familyName != "Pretendard" {
            log.error("Pretendard not found; HUD overlay may use fallback glyphs.")
        }
        self.labelFont = label
        self.valueFont = value
    }

    public func renderImage(size: CGSize, data: HUDOverlayData) -> CGImage? {
        guard size.width > 1, size.height > 1 else { return nil }
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        )
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        draw(in: context, size: size, data: data)
        return context.makeImage()
    }

    public func draw(in context: CGContext, size: CGSize, data: HUDOverlayData) {
        let graphics = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics

        let rows = buildRows(data: data)
        let metrics = rows.map { rowMetrics(label: $0.0, value: $0.1) }
        let totalHeight = metrics.reduce(0) { $0 + $1.height } + rowSpacing * CGFloat(max(0, metrics.count - 1))
        var currentY = max(margin, size.height - margin - totalHeight)

        for (index, metric) in metrics.enumerated() {
            let rect = CGRect(x: margin, y: currentY, width: metric.width, height: metric.height)
            drawRowBackground(rect: rect)
            drawRowText(rect: rect, label: rows[index].0, value: rows[index].1)
            currentY += metric.height + rowSpacing
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    private func buildRows(data: HUDOverlayData) -> [(String, String)] {
        let fpsText = data.fps > 0 ? String(format: "%.3f", data.fps) : "—"
        let resText: String
        if data.resolution != .zero {
            resText = "\(Int(data.resolution.width))x\(Int(data.resolution.height))"
        } else {
            resText = "—"
        }
        return [
            ("TC", data.timecode),
            ("Frame", "\(data.frameIndex)"),
            ("FPS", fpsText),
            ("Res", resText)
        ]
    }

    private func rowMetrics(label: String, value: String) -> (width: CGFloat, height: CGFloat) {
        let labelSize = (label as NSString).size(withAttributes: [.font: labelFont])
        let valueSize = (value as NSString).size(withAttributes: [.font: valueFont])
        let height = max(labelSize.height, valueSize.height) + paddingY * 2
        let width = labelSize.width + valueSize.width + labelSpacing + paddingX * 2
        return (width: width, height: height)
    }

    private func drawRowBackground(rect: CGRect) {
        backgroundColor.setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.fill()
    }

    private func drawRowText(rect: CGRect, label: String, value: String) {
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: labelColor
        ]
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: valueColor
        ]

        let labelSize = (label as NSString).size(withAttributes: labelAttributes)
        let valueSize = (value as NSString).size(withAttributes: valueAttributes)

        let textY = rect.origin.y + (rect.height - max(labelSize.height, valueSize.height)) / 2
        let labelPoint = CGPoint(x: rect.origin.x + paddingX, y: textY)
        let valuePoint = CGPoint(x: rect.origin.x + paddingX + labelSize.width + labelSpacing, y: textY)

        (label as NSString).draw(at: labelPoint, withAttributes: labelAttributes)
        (value as NSString).draw(at: valuePoint, withAttributes: valueAttributes)
    }

    private static func makeFont(name: String, size: CGFloat) -> NSFont {
        if let font = NSFont(name: name, size: size) {
            return font
        }
        let ctFont = CTFontCreateWithName(name as CFString, size, nil)
        return ctFont as NSFont
    }
}
